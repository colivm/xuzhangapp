import Foundation
import os.log

struct HomeItem: Identifiable, Codable, Equatable {
    struct MemoryContext: Codable, Equatable {
        var weatherKind: String?
        var temperatureCelsius: Double?
        var cityName: String?
        var semanticPlace: String?
    }

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
            case .health: return "🏃"
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
    var userEditedCategory: Bool?
    var categoryCorrectionFrom: Category?
    var memoryContext: MemoryContext?
    var scenePackId: String?
    var memoryImageData: Data?
    var memoryImageDatas: [Data]

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
        userEditedTitle: Bool? = nil,
        userEditedCategory: Bool? = nil,
        categoryCorrectionFrom: Category? = nil,
        memoryContext: MemoryContext? = nil,
        scenePackId: String? = nil,
        memoryImageData: Data? = nil,
        memoryImageDatas: [Data] = []
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
        self.userEditedCategory = userEditedCategory
        self.categoryCorrectionFrom = categoryCorrectionFrom
        self.memoryContext = memoryContext
        self.scenePackId = scenePackId
        let normalizedImages = memoryImageDatas.isEmpty ? memoryImageData.map { [$0] } ?? [] : memoryImageDatas
        self.memoryImageDatas = normalizedImages
        self.memoryImageData = normalizedImages.first
    }

    static func inferEmotionTag(category: Category, amount: Double) -> String {
        switch category {
        case .dining: return amount >= 40 ? "认真吃了一顿" : "日常餐饮"
        case .transport: return amount >= 20 ? "去远一点" : "日常出行"
        case .shopping: return amount >= 100 ? "计划内添置" : "日常添置"
        case .daily: return amount >= 50 ? "日用补齐" : "日用记录"
        case .entertainment: return amount >= 150 ? "一次娱乐安排" : "轻量娱乐"
        case .lodging: return amount >= 300 ? "住宿安排" : "短暂停留"
        case .health: return amount >= 100 ? "健康支出" : "健康记录"
        case .home: return amount >= 300 ? "居家安排" : "居家补给"
        case .social: return amount >= 100 ? "人情往来" : "见面记录"
        case .other: return amount >= 80 ? "单独记录" : "日常记录"
        }
    }

    var displayEmotionTag: String {
        let trimmed = emotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let lateCommute = Self.lateWorkCommuteEmotionTag(for: self),
           Self.shouldPreferLateWorkCommuteTag(current: trimmed) {
            return lateCommute
        }
        if Self.isAggregateStyleEmotionTag(trimmed) {
            return Self.singleRecordEmotionTag(for: self)
        }
        if category == .dining,
           Self.containsDrinkKeyword(title),
           Self.isMealDiningTag(trimmed) {
            return Self.drinkDiningDisplayTag(from: trimmed)
        }
        if !RecordSemanticLexicon.isTitle(trimmed, compatibleWith: category),
           !(category == .dining && Self.containsConvenienceStoreKeyword("\(title) \(trimmed)")) {
            return Self.inferEmotionTag(category: category, amount: amount)
        }
        if Self.containsTravelKeyword(trimmed),
           category != .lodging,
           !Self.containsTravelKeyword(title) {
            return Self.inferEmotionTag(category: category, amount: amount)
        }
        if category == .dining,
           Self.isWeekend(createdAt),
           Self.containsWorkMealKeyword(trimmed),
           !Self.containsWeekendWorkMealCue(title) {
            return Self.weekendDiningTag(for: createdAt, amount: amount)
        }
        if category == .transport,
           Self.isWeekend(createdAt),
           Self.containsWorkRouteKeyword(trimmed),
           !Self.containsWeekendWorkRouteCue(title) {
            return Self.weekendRouteTag(for: createdAt)
        }
        if Self.isGenericRainDailyTag(trimmed),
           !Self.containsWeatherSupplyKeyword(title) {
            if let refined = Self.refinedEmotionTag(title: title, category: category, amount: amount, date: createdAt) {
                return refined
            }
            return Self.inferEmotionTag(category: category, amount: amount)
        }
        if let refined = Self.refinedEmotionTag(title: title, category: category, amount: amount, date: createdAt),
           Self.shouldPreferRefinedTag(current: trimmed, refined: refined) {
            return refined
        }
        return trimmed
    }

    var hasMeaningfulTitle: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed == RecordSemanticLexicon.emptyNoteTitle { return false }
        if trimmed == category.defaultRecordTitle { return false }
        return true
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hasMeaningfulTitle else { return trimmed }
        return "\(category.rawValue) \(createdAt.zhBillTime)"
    }

    static func refinedEmotionTag(title: String, category: Category, amount: Double, date: Date? = nil) -> String? {
        // TODO: migrate dining/transport detail rules into RecordSceneLexicon scene-level data.
        // This switch is category-scoped, so a transport record titled "咖啡" cannot return a dining tag.
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return nil }

        switch category {
        case .health:
            if containsAny(text, ["游泳", "泳池", "泳馆", "泳票", "泳道"]) {
                if containsAny(text, ["次票", "次卡", "单次", "票"]) { return "游泳次票记下" }
                if containsAny(text, ["课", "私教", "训练"]) { return "游泳课记一回" }
                return "今天下水一回"
            }
            if containsAny(text, ["健身房", "健身卡", "健身会员", "月卡", "年卡"]) {
                return amount >= 300 ? "健身会员安排" : "健身卡次记下"
            }
            if containsAny(text, ["瑜伽", "普拉提", "团课", "私教", "课包"]) {
                return amount >= 200 ? "课程安排记下" : "一节课程记下"
            }
            if containsAny(text, ["羽毛球", "网球", "篮球", "足球", "乒乓", "台球", "球馆", "场地", "订场"]) {
                return "运动场地一回"
            }
            if containsAny(text, ["跑步", "骑行", "马拉松", "攀岩", "滑雪", "滑冰", "舞蹈", "拳击"]) {
                return "运动安排记下"
            }
            if containsAny(text, ["体检", "检查", "挂号", "问诊", "门诊", "医院", "诊所", "拍片", "验血"]) {
                return amount >= 200 ? "检查项目记下" : "问诊检查一回"
            }
            if containsAny(text, ["牙", "口腔", "洗牙", "补牙", "牙线", "牙膏", "牙刷"]) {
                return "口腔护理一回"
            }
            if containsAny(text, ["配镜", "验光", "眼镜"]) {
                return "视力护理一回"
            }
            if containsAny(text, ["医美", "医美脱毛", "光子嫩肤", "水光针"]) {
                return "身体护理安排"
            }
            if containsAny(text, ["药", "药店", "感冒", "退烧", "消炎", "止痛", "维生素", "眼药水", "创可贴"]) {
                return "药品护理记下"
            }
            if containsAny(text, ["按摩", "理疗", "康复", "护具", "筋膜", "贴膏", "膏药", "蛋白", "补剂", "能量胶"]) {
                return "恢复护理安排"
            }
        case .dining:
            if containsAny(text, ["夜市", "夜摊", "夜市摊", "大排档"]) {
                if containsAny(text, ["烤", "烧烤", "串", "生蚝", "海鲜", "小龙虾", "鱿鱼", "铁板"]) { return "夜市摊上吃点热的" }
                if containsAny(text, ["炒饭", "炒粉", "炒面", "米粉", "粉", "面", "饭"]) { return "夜市里的一份热乎" }
                return "夜市里吃点东西"
            }
            if containsAny(text, ["铁板鱿鱼", "烤鱿鱼", "烤生蚝", "生蚝", "烧烤", "烤冷面", "串串", "烤串", "大排档", "夜市", "夜摊"]) { return "路边摊吃点热闹" }
            if containsAny(text, ["绝味", "鸭脖", "鸭货", "卤味", "周黑鸭", "煌上煌"]) { return "卤味小食记下" }
            if containsAny(text, ["夜宵", "深夜", "夜里", "凌晨"]) { return "夜里补一点" }
            if let lateNightTag = lateNightDiningEmotionTag(title: text, date: date) {
                return lateNightTag
            }
            if containsAny(text, ["早餐", "早饭"]) { return "早餐先记下" }
            if containsAny(text, ["豆浆", "包子"]) {
                guard let date else { return "热乎一口记下" }
                let hour = Calendar.current.component(.hour, from: date)
                switch hour {
                case 5..<10:
                    return "早餐先记下"
                case 11..<14:
                    return "中午垫一口"
                case 17..<21:
                    return "晚饭先垫一下"
                case 21...23, 0..<5:
                    return "夜里一口热的"
                default:
                    return "热乎一口记下"
                }
            }
            if containsAny(text, ["茶叶蛋", "饭团", "关东煮", "便当", "三明治"]) {
                guard let date else { return "便利店小食记下" }
                let hour = Calendar.current.component(.hour, from: date)
                switch hour {
                case 5..<10:
                    return "早餐先记下"
                case 11..<14:
                    return "中午垫一口"
                case 17..<21:
                    return "晚饭先垫一下"
                case 21...23, 0..<5:
                    return "夜里一口热的"
                default:
                    return "便利店小食记下"
                }
            }
            if containsDrinkKeyword(text) { return "买杯喝的" }
            if containsAny(text, ["午餐", "午饭", "中午"]) { return "中午一顿饭" }
            if containsAny(text, ["晚餐", "晚饭"]) { return "晚饭时间坐一会儿" }
            if containsAny(text, ["烤生蚝", "烤鱿鱼", "铁板鱿鱼", "烤冷面", "烧烤", "串串", "烤串", "大排档"]) { return "路边摊吃点热闹" }
            if containsAny(text, ["火锅", "烤肉"]) { return "认真吃一顿" }
            if containsAny(text, ["烤鸭", "烧鸭", "卤鸭", "鸭肉"]) { return "烤鸭这份记下" }
            if containsAny(text, ["肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴", "面", "粉", "馄饨", "饺子", "盖饭", "米线", "麻辣烫"]) { return "热乎一份记下" }
            if containsAny(text, ["甜品", "蛋糕", "面包", "冰淇淋", "冰粉", "糖水"]) { return "给今天一点甜" }
            if containsAny(text, ["水果", "酸奶", "轻食", "沙拉"]) { return "轻轻补一点" }
            if containsAny(text, ["买菜", "菜场", "生鲜", "超市菜"]) { return "回家做饭的料" }
        case .transport:
            if let lateCommute = lateWorkCommuteEmotionTag(title: title, category: category, date: date) {
                return lateCommute
            }
            if containsAny(text, ["停车", "停车费", "车位"]) { return "车停稳了" }
            if containsAny(text, ["加油", "油费", "充车", "充电桩", "电车充电", "汽车充电", "车辆充电", "新能源充电", "补能"]) { return "给车补点能量" }
            if containsAny(text, ["洗车"]) { return "车洗干净了" }
            if containsAny(text, ["汽车保养", "车辆保养", "保养车"]) { return "车保养一回" }
            if containsAny(text, ["打车", "出租", "网约车", "滴滴", "花小猪"]) { return "打车这一程" }
            if containsAny(text, ["地铁", "公交", "巴士"]) { return "公共交通一段" }
            if containsAny(text, ["共享单车", "单车", "骑车", "电动车"]) { return "短短骑一程" }
            if containsAny(text, ["高铁", "火车", "动车", "车票"]) { return "远一点的路" }
            if containsAny(text, ["机票", "机场", "航班"]) { return "飞一程记下" }
            if containsAny(text, ["高速", "过路费", "etc"]) { return "路上通行一笔" }
        case .shopping:
            if containsAny(text, ["Office 365", "Microsoft 365", "Adobe订阅", "Creative Cloud", "Notion订阅", "Notion会员"]) {
                return "数字服务续上"
            }
            if containsAny(text, ["渔具", "鱼竿", "鱼线", "鱼饵", "路亚", "钓箱", "钓椅"]) {
                return "给喜欢的事添点装备"
            }
            if containsAny(text, ["露营", "帐篷", "天幕", "睡袋", "骑行", "头盔", "摄影", "相机", "镜头", "模型", "手办", "谷子", "潮玩", "吧唧", "徽章", "亚克力", "立牌", "盲盒", "泡泡玛特", "POP MART", "POPMART", "LABUBU", "棉花娃娃", "痛包", "同人本", "乙游周边", "漫展周边", "乐器", "吉他", "键盘"]) {
                return "爱好里的小投入"
            }
            if containsAny(text, ["奶粉"]) { return "宝宝口粮补上" }
            if containsAny(text, ["尿不湿", "纸尿裤", "拉拉裤"]) { return "照护用品补齐" }
            if containsAny(text, ["辅食", "奶瓶", "安抚奶嘴", "托育费", "托班费", "幼儿园学费", "早教课"]) { return "宝宝照护补上" }
            if containsAny(text, ["狗粮", "猫粮", "宠物粮", "宠物口粮"]) { return "毛孩子口粮补上" }
            if containsAny(text, ["猫砂", "尿垫", "冻干", "宠物罐头", "罐头"]) { return "毛孩子日常补给" }
            if containsAny(text, ["衣服", "上衣", "裤子", "裙", "外套", "内衣"]) { return "给衣柜添一件" }
            if containsAny(text, ["鞋", "袜"]) { return "脚下换新一点" }
            if containsAny(text, ["护肤", "洗面奶", "面霜", "防晒", "口红", "化妆"]) { return "洗护美妆补上" }
            if containsAny(text, ["手机", "耳机", "充电器", "数据线", "充电宝", "电脑", "键盘"]) { return "数码小物到位" }
            if containsAny(text, ["书", "文具", "本子", "笔"]) { return "书桌添点东西" }
            if containsAny(text, ["花", "香薰", "摆件"]) { return "给日子添点好看" }
            if containsAny(text, ["快递", "运费"]) { return "路上的小费用" }
        case .daily:
            if containsAny(text, ["奶粉"]) { return "宝宝口粮补上" }
            if containsAny(text, ["尿不湿", "纸尿裤", "拉拉裤"]) { return "照护用品补齐" }
            if containsAny(text, ["辅食", "奶瓶", "安抚奶嘴"]) { return "宝宝照护补上" }
            if containsAny(text, ["狗粮", "猫粮", "宠物粮", "宠物口粮"]) { return "毛孩子口粮补上" }
            if containsAny(text, ["猫砂", "尿垫", "冻干", "宠物罐头", "罐头"]) { return "毛孩子日常补给" }
            if containsAny(text, ["纸巾", "卷纸", "抽纸", "湿巾"]) { return "纸品补上了" }
            if containsAny(text, ["洗衣液", "洗洁精", "清洁", "垃圾袋", "消毒"]) { return "清洁用品补齐" }
            if containsAny(text, ["洗发水", "沐浴露", "牙刷", "毛巾"]) { return "洗护日常补上" }
            if containsAny(text, ["理发", "剪发", "洗剪吹"]) { return "头发清爽一下" }
            if containsAny(text, ["鸡蛋", "山姆", "山姆会员", "永辉", "永辉超市", "大润发", "钱大妈", "牛奶", "鲜奶", "纯牛奶", "酸奶", "认养一头牛"]) { return "家里吃的补上" }
            if containsAny(text, ["打印", "复印", "证件照", "照片"]) { return "临时办点事" }
            if containsAny(text, ["钥匙", "配钥匙", "锁"]) { return "生活小修补" }
            if containsAny(text, ["雨伞", "伞"]) { return "给天气留个准备" }
        case .entertainment:
            if containsAny(text, ["电影", "影院"]) { return "看场电影" }
            if containsAny(text, ["B站会员", "哔哩哔哩会员", "爱奇艺会员", "腾讯视频会员", "优酷会员", "芒果TV会员", "网易云会员", "网易云音乐会员", "QQ音乐会员", "喜马拉雅会员", "百度网盘会员", "WPS会员", "iCloud订阅", "Apple Music"]) { return "数字订阅续上" }
            if containsAny(text, ["网吧", "网咖", "上网费"]) { return "上网娱乐一回" }
            if containsAny(text, ["直播打赏", "主播打赏", "抖音打赏", "直播礼物"]) { return "直播互动记下" }
            if containsAny(text, ["游戏", "点券", "皮肤"]) { return "娱乐里充一笔" }
            if containsAny(text, ["演唱会", "音乐节", "live", "话剧", "剧场"]) { return "看一场现场" }
            if containsAny(text, ["展", "博物馆", "美术馆"]) { return "出去看点东西" }
            if containsAny(text, ["ktv", "唱歌"]) { return "唱一会儿" }
            if containsAny(text, ["桌游", "密室", "剧本杀"]) { return "和人玩一局" }
        case .lodging:
            if containsAny(text, ["酒店", "宾馆"]) { return "住一晚记下" }
            if containsAny(text, ["民宿", "客栈"]) { return "今晚落脚这里" }
            if containsAny(text, ["电竞酒店"]) { return "电竞酒店一晚" }
            if containsAny(text, ["房费", "续住", "押金"]) { return "住宿安排一笔" }
        case .home:
            if containsAny(text, ["房租", "租金"]) { return "住处安稳下来" }
            if containsAny(text, ["水费", "电费", "燃气", "煤气", "暖气费", "取暖费", "供暖费", "采暖费", "热力费", "供热费", "暖气缴费", "热力公司", "网上国网", "国网"]) { return "家里运转一笔" }
            if containsAny(text, ["物业", "宽带", "网费"]) { return "居家固定支出" }
            if containsAny(text, ["搬家", "搬家公司", "货拉拉搬家"]) { return "搬家安排记下" }
            if containsAny(text, ["保洁", "家政", "钟点工", "开荒保洁", "上门保洁", "深度保洁", "擦玻璃", "清洗油烟机", "空调清洗"]) { return "家里清洁一回" }
            if containsAny(text, ["维修", "修理", "师傅", "换锁", "疏通"]) { return "家里修一处" }
            if containsAny(text, ["锅", "碗", "厨房", "床品", "收纳", "灯"]) { return "给家添点方便" }
            if containsAny(text, ["冰箱", "洗衣机", "空调", "家电"]) { return "家电安排一笔" }
        case .social:
            if containsAny(text, ["礼物", "送礼", "伴手礼"]) { return "带点心意" }
            if containsAny(text, ["白事", "白事随礼", "奠仪", "帛金", "花圈"]) { return "重要人情记下" }
            if containsAny(text, ["红包", "份子", "随礼"]) { return "人情往来一笔" }
            if containsAny(text, ["生日", "蛋糕"]) { return "生日里的心意" }
            if containsAny(text, ["婚礼", "满月", "乔迁"]) { return "重要日子记下" }
            if containsAny(text, ["探望", "看望", "拜访"]) { return "去见挂念的人" }
            if containsAny(text, ["请客", "聚餐", "朋友"]) { return "见面吃一顿" }
        case .other:
            if containsAny(text, ["打印", "复印", "证件照"]) { return "临时办点事" }
            if containsAny(text, ["驾校", "驾校报名费", "驾考", "学车"]) { return "学车安排记下" }
            if containsAny(text, ["彩票", "福彩", "体彩", "刮刮乐"]) { return "这笔单独记下" }
            if containsAny(text, ["押金", "保证金"]) { return "先垫一笔" }
            if containsAny(text, ["手续费", "服务费"]) { return "小费用记下" }
            if containsAny(text, ["罚款", "违章"]) { return "不太想记也记下" }
        }

        return nil
    }

    static func lateNightDiningEmotionTag(title: String, date: Date?) -> String? {
        guard let date else { return nil }
        let hour = Calendar.current.component(.hour, from: date)
        guard (21...23).contains(hour) || (0..<5).contains(hour) else { return nil }

        let text = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return "夜里吃点东西" }

        let hasExplicitDayMeal = containsAny(text, ["早餐", "早饭", "午餐", "午饭", "中午"])
        let hasNightCue = containsAny(text, ["夜宵", "宵夜", "深夜", "夜里", "凌晨", "晚归", "加班", "下班后"])
        guard hasNightCue || !hasExplicitDayMeal else { return nil }

        if containsAny(text, ["加班", "晚归", "下班后"]) {
            if containsAny(text, ["热乎", "热饭", "热食", "热汤", "热的"]) {
                return "加班后吃点热乎的"
            }
            return "晚点吃上了"
        }
        if containsAny(text, ["夜市", "夜摊", "大排档"]) {
            if containsAny(text, ["烤", "烧烤", "串", "生蚝", "海鲜", "小龙虾", "鱿鱼", "铁板"]) { return "夜市摊上吃点热的" }
            return "夜市里吃点东西"
        }
        if containsAny(text, ["热乎", "热饭", "热食", "热汤", "热的", "面", "粉", "馄饨", "麻辣烫"]) {
            return "夜里一口热的"
        }
        if containsAny(text, ["饭", "餐", "吃", "外卖", "小食", "点心", "垫一下", "垫一口"]) {
            return "夜里吃点东西"
        }
        return nil
    }

    static func isLateWorkCommute(_ item: HomeItem) -> Bool {
        lateWorkCommuteEmotionTag(for: item) != nil
    }

    static func lateWorkCommuteEmotionTag(for item: HomeItem) -> String? {
        lateWorkCommuteEmotionTag(
            title: "\(item.title) \(item.emotionTag)",
            category: item.category,
            date: item.createdAt,
            weatherKind: item.memoryContext?.weatherKind
        )
    }

    static func lateWorkCommutePlaybackTitle(for item: HomeItem) -> String? {
        guard isLateWorkCommute(item) else { return nil }
        let text = "\(item.title) \(item.emotionTag)".lowercased()
        return containsWorkCommuteCue(text) ? "晚下班路上" : "晚上通勤路上"
    }

    static func lateWorkCommutePlaybackLine(for item: HomeItem) -> String? {
        guard isLateWorkCommute(item) else { return nil }
        let text = "\(item.title) \(item.emotionTag)".lowercased()
        let timeText = lateCommuteTimeText(for: item.createdAt)
        let rainy = isRainyWeather(item.memoryContext?.weatherKind) || text.contains("雨")
        if containsWorkCommuteCue(text) {
            return rainy
                ? "\(timeText)还在下班路上，又赶上雨，今天辛苦了。到家先缓一缓。"
                : "\(timeText)还在下班路上，今天收得有点晚。到家先缓一缓。"
        }
        return rainy
            ? "\(timeText)的通勤带着雨，路上更费心一点。到家先缓一缓。"
            : "\(timeText)的通勤记下来了，路上的这段也算今天的一部分。"
    }

    static func lateWorkCommuteTraceLine(for item: HomeItem) -> String? {
        guard isLateWorkCommute(item) else { return nil }
        let text = "\(item.title) \(item.emotionTag)".lowercased()
        let timeText = lateCommuteTimeText(for: item.createdAt)
        let rainy = isRainyWeather(item.memoryContext?.weatherKind) || text.contains("雨")
        if rainy, containsWorkCommuteCue(text) {
            return "\(timeText)的下班路还遇上雨，账本里有这段晚归。"
        }
        if containsWorkCommuteCue(text) {
            return "\(timeText)的下班路记下来了，今天工作收得有点晚。"
        }
        return "\(timeText)的通勤记下来了，今天回到家的路也有了位置。"
    }

    private static func shouldPreferRefinedTag(current: String, refined: String) -> Bool {
        guard current != refined else { return false }
        let genericExact = [
            "健康记录", "健康支出", "健康相关一笔", "身体相关大笔支出", "身体项目记清楚",
            "身体提醒先记下", "基础护理用品", "今天的护理记录", "身体小用品", "健康小物补齐",
            "运动后买点恢复用品", "运动恢复用品补齐", "运动后补给", "训练恢复补给",
            "运动小补给", "身体恢复安排", "身体相关安排", "今天的运动安排",
            "日常餐饮", "认真吃了一顿", "去远一点", "日常出行", "计划内添置", "日常添置",
            "日用补齐", "日用记录", "一次娱乐安排", "轻量娱乐", "住宿安排", "短暂停留",
            "居家安排", "居家补给", "人情往来", "见面记录", "单独记录", "日常记录",
            "中午一顿饭", "饭点记一笔", "热饭到了手边", "今天吃上饭", "这一顿先记下",
            "简单吃一顿", "认真吃一顿", "晚饭记一笔"
        ]
        if genericExact.contains(current) { return true }
        let genericFragments = ["恢复用品", "恢复补给", "健康相关", "身体相关", "护理用品", "日常记录"]
        return genericFragments.contains { current.contains($0) }
    }

    private static func lateWorkCommuteEmotionTag(
        title: String,
        category: Category,
        date: Date?,
        weatherKind: String? = nil
    ) -> String? {
        guard category == .transport, let date else { return nil }
        let hour = Calendar.current.component(.hour, from: date)
        guard (21...23).contains(hour) || (0..<5).contains(hour) else { return nil }
        let text = title.lowercased()
        guard containsLateCommuteCue(text) else { return nil }
        let rainy = isRainyWeather(weatherKind) || text.contains("雨")
        if rainy, containsWorkCommuteCue(text) {
            return "晚下班遇上雨，慢点到家"
        }
        if containsWorkCommuteCue(text) {
            return "晚下班路上辛苦了"
        }
        if rainy {
            return "晚上通勤遇上雨"
        }
        return "晚上这段通勤"
    }

    private static func shouldPreferLateWorkCommuteTag(current: String) -> Bool {
        let text = current.lowercased()
        let generic = [
            "日常出行", "出行记录", "傍晚一段路", "公共交通一段", "公交地铁这一趟",
            "通勤路上", "连续", "雨天通勤", "雪天通勤", "冷天出门", "热天路上",
            "下班路上这一程", "下班这趟路到家了", "打车这一程"
        ]
        return containsAny(text, generic)
    }

    private static func containsLateCommuteCue(_ text: String) -> Bool {
        containsAny(text.lowercased(), ["下班", "通勤", "晚高峰", "加班", "工作", "公司", "单位", "工位", "地铁", "公交", "轨道交通", "打车", "滴滴", "网约车", "回家", "到家"])
    }

    private static func containsWorkCommuteCue(_ text: String) -> Bool {
        containsAny(text.lowercased(), ["下班", "加班", "工作", "公司", "单位", "工位"])
    }

    private static func isRainyWeather(_ weatherKind: String?) -> Bool {
        let text = weatherKind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return text.contains("雨") || text.contains("rain")
    }

    private static func lateCommuteTimeText(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 21: return "晚上九点多"
        case 22: return "晚上十点多"
        case 23: return "晚上十一点多"
        case 0: return "凌晨零点多"
        case 1: return "凌晨一点多"
        case 2: return "凌晨两点多"
        case 3: return "凌晨三点多"
        case 4: return "凌晨四点多"
        default: return "晚上"
        }
    }

    private static func containsTravelKeyword(_ text: String) -> Bool {
        let keywords = ["旅行", "旅途", "景区", "景点", "行程", "酒店", "民宿", "住宿", "机票", "高铁", "机场", "返程", "摆渡"]
        return keywords.contains { text.contains($0) }
    }

    private static func containsConvenienceStoreKeyword(_ text: String) -> Bool {
        ["便利蜂", "便利店", "全家", "罗森", "711", "7-11", "美宜佳", "茶叶蛋", "饭团", "关东煮"].contains {
            text.localizedCaseInsensitiveContains($0)
        }
    }

    private static func containsDrinkKeyword(_ text: String) -> Bool {
        containsAny(text.lowercased(), ["咖啡", "拿铁", "美式", "奶茶", "饮品", "饮料", "喝的", "茶饮", "果汁", "柠檬茶", "水溶", "c100", "维c", "维他", "瑞幸", "星巴克", "manner", "蜜雪", "喜茶", "奈雪"])
    }

    private static func isMealDiningTag(_ text: String) -> Bool {
        containsAny(text.lowercased(), ["好" + "好吃饭", "吃上饭", "饭点", "一顿饭", "这一顿", "简单吃一顿", "认真吃一顿", "晚饭", "热饭"])
    }

    private static func drinkDiningDisplayTag(from current: String) -> String {
        return "买杯喝的"
    }

    private static func isAggregateStyleEmotionTag(_ text: String) -> Bool {
        if text.contains("连续"), text.contains("天") {
            return true
        }
        if text.contains("第一次") || text.contains("首次") {
            return true
        }
        if text.contains("第"), text.contains("次") {
            return true
        }
        return false
    }

    private static func singleRecordEmotionTag(for item: HomeItem) -> String {
        let resolved = NarrativeCopyResolver.resolveEmotionTag(
            context: NarrativeCopyResolver.Context(
                brandId: item.merchantBrandId,
                category: item.category,
                amount: item.amount,
                date: item.createdAt,
                seed: item.title,
                note: item.title,
                scenePackId: item.scenePackId
            )
        )
        if RecordSemanticLexicon.isTitle(resolved, compatibleWith: item.category) {
            return resolved
        }
        if let refined = Self.refinedEmotionTag(
            title: item.title,
            category: item.category,
            amount: item.amount,
            date: item.createdAt
        ) {
            return refined
        }
        return Self.inferEmotionTag(category: item.category, amount: item.amount)
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }

    private static func isGenericRainDailyTag(_ text: String) -> Bool {
        text.contains("下雨天补齐日常") || text.contains("雨天补齐日常")
    }

    private static func containsWeatherSupplyKeyword(_ text: String) -> Bool {
        containsAny(text.lowercased(), ["雨伞", "伞", "雨衣", "雨鞋", "防水", "烘干", "除湿"])
    }

    private static func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private static func containsWorkMealKeyword(_ text: String) -> Bool {
        ["食堂", "工位", "工作日", "工作餐", "忙里", "加班后"].contains { text.contains($0) }
    }

    private static func containsWeekendWorkMealCue(_ text: String) -> Bool {
        if text.contains("周末食堂") { return true }
        let mealCue = ["食堂", "午餐", "饭", "餐", "外卖", "热饭"].contains { text.contains($0) }
        let workCue = ["加班", "公司", "单位", "工位", "工作餐"].contains { text.contains($0) }
        return mealCue && workCue
    }

    private static func containsWorkRouteKeyword(_ text: String) -> Bool {
        ["上班", "下班", "到岗", "通勤", "加班", "工作", "早高峰", "晚高峰"].contains { text.contains($0) }
    }

    private static func containsWeekendWorkRouteCue(_ text: String) -> Bool {
        let routeCue = ["地铁", "公交", "打车", "车", "路", "通勤"].contains { text.contains($0) }
        let workCue = ["加班", "公司", "单位", "工位", "到岗", "上班", "下班"].contains { text.contains($0) }
        return routeCue && workCue
    }

    private static func weekendDiningTag(for date: Date, amount: Double) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<10: return "周末早餐"
        case 11..<14: return "周末午餐"
        case 17..<21: return "周末晚饭"
        default: return amount >= 40 ? "认真吃了一顿" : "简单吃一顿"
        }
    }

    private static func weekendRouteTag(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return "早上出门"
        case 17..<22: return "傍晚一段路"
        default: return "日常出行"
        }
    }
}

extension HomeItem {
    enum CodingKeys: String, CodingKey {
        case id, title, amount, category, source, createdAt, updatedAt, emotionTag, merchantBrandId, draftMeta, userEditedTitle, userEditedCategory, categoryCorrectionFrom, memoryContext, scenePackId, memoryImageData, memoryImageDatas
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
        userEditedCategory = try container.decodeIfPresent(Bool.self, forKey: .userEditedCategory)
        categoryCorrectionFrom = try container.decodeIfPresent(Category.self, forKey: .categoryCorrectionFrom)
        memoryContext = try container.decodeIfPresent(MemoryContext.self, forKey: .memoryContext)
        scenePackId = try container.decodeIfPresent(String.self, forKey: .scenePackId)
        let legacyImageData = try container.decodeIfPresent(Data.self, forKey: .memoryImageData)
        let decodedImages = try container.decodeIfPresent([Data].self, forKey: .memoryImageDatas) ?? []
        memoryImageDatas = decodedImages.isEmpty ? legacyImageData.map { [$0] } ?? [] : decodedImages
        memoryImageData = memoryImageDatas.first
    }

    var memoryImages: [Data] {
        get {
            if !memoryImageDatas.isEmpty { return memoryImageDatas }
            return memoryImageData.map { [$0] } ?? []
        }
        set {
            memoryImageDatas = newValue
            memoryImageData = newValue.first
        }
    }

    var coverMemoryImageData: Data? {
        memoryImages.first
    }

    var hasMemoryImages: Bool {
        !memoryImages.isEmpty
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

    var zhBillDateOnly: String {
        if !Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year) {
            return Date.zhBillDateOnlyWithYearFormatter.string(from: self)
        }
        return Date.zhBillDateOnlyFormatter.string(from: self)
    }

    /// 「M月d日 周X HH:mm」——用于通勤补记等需要快速判断工作日/周末的场景。
    var zhBillDateTimeWithWeekday: String {
        if !Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year) {
            return Date.zhBillDateTimeWithYearAndWeekdayFormatter.string(from: self)
        }
        return Date.zhBillDateTimeWithWeekdayFormatter.string(from: self)
    }

    /// 「M月d日 周X」——用于洞察/记忆卡片等只显示日期且需要星期的场景。
    var zhBillDateOnlyWithWeekday: String {
        if !Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year) {
            return Date.zhBillDateOnlyWithYearAndWeekdayFormatter.string(from: self)
        }
        return Date.zhBillDateOnlyWithWeekdayFormatter.string(from: self)
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

    private static let zhBillDateTimeWithWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "M月d日 EEE HH:mm"
        return formatter
    }()

    private static let zhBillDateTimeWithYearAndWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月d日 EEE HH:mm"
        return formatter
    }()

    private static let zhBillTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let zhBillDateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let zhBillDateOnlyWithYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    private static let zhBillDateOnlyWithWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "M月d日 EEE"
        return formatter
    }()

    private static let zhBillDateOnlyWithYearAndWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月d日 EEE"
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
    var snapshotSignature: String?

    init(
        id: UUID = UUID(),
        dayKey: String,
        summary: String,
        action: String,
        encourage: String,
        createdAt: Date = Date(),
        snapshotSignature: String? = nil
    ) {
        self.id = id
        self.dayKey = dayKey
        self.summary = summary
        self.action = action
        self.encourage = encourage
        self.createdAt = createdAt
        self.snapshotSignature = snapshotSignature
    }
}

// MARK: - Record Semantic Lexicon

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

    private static let strongManualNoteOverrideRules: [(category: HomeItem.Category, keywords: [String])] = [
        (.dining, ["茶叶蛋", "饭团", "关东煮", "便当", "三明治", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴", "咖啡", "奶茶", "拿铁", "美式"]),
        (.transport, ["地铁", "公交", "打车", "滴滴", "花小猪", "网约车", "通勤", "早高峰", "晚高峰", "高铁", "机票", "机场", "充电桩", "电车充电", "汽车充电"]),
        (.daily, ["纸巾", "抽纸", "卷纸", "湿巾", "洗衣液", "洗衣凝珠", "垃圾袋", "话费", "手机话费", "手机充值", "中国移动", "中国联通", "中国电信", "山姆会员"]),
        (.home, ["房租", "电费", "燃气", "物业", "宽带", "暖气费", "取暖费", "供暖费", "热力费", "家政", "保洁", "搬家"]),
        (.shopping, ["手机充电器", "数据线", "充电宝", "泡泡玛特", "POP MART", "谷子", "潮玩", "盲盒"]),
        (.entertainment, ["网吧", "网咖", "上网费", "腾讯视频会员", "爱奇艺会员", "网易云音乐会员", "QQ音乐会员", "直播打赏"]),
        (.health, ["药店", "医院", "挂号", "门诊", "体检", "洗牙", "配镜", "健身房", "私教"]),
        (.lodging, ["酒店", "民宿", "住宿", "电竞酒店"]),
        (.social, ["红包", "随礼", "份子钱", "白事随礼", "奠仪", "帛金"]),
        (.other, ["驾校", "驾校报名费", "彩票", "刮刮乐"])
    ]

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
        return minimalFallbackPayload
    }

    private static let minimalFallbackPayload = RecordSceneLexiconPayload(
        version: 0,
        keywordRules: [
            .init(category: .transport, score: 4.0, keywords: ["地铁", "公交", "打车", "滴滴", "花小猪", "洗车", "汽车保养", "车辆保养", "保养车", "ETC", "etc", "充车", "充电桩", "电车充电", "汽车充电", "车辆充电", "新能源充电", "补能", "高铁", "机票", "机场", "路费", "通勤"]),
            .init(category: .dining, score: 4.8, keywords: ["咖啡", "奶茶", "早餐", "早饭", "午餐", "午饭", "晚餐", "晚饭", "夜宵", "宵夜", "外卖", "饭", "餐", "一顿", "这顿", "吃", "垫一下", "垫一口", "夜里补", "热食", "热乎", "轻食", "小食", "点心", "补点能量", "吃一口", "饮品", "饮料", "喝的", "可乐", "雪碧", "汽水", "果汁", "水溶", "c100", "维C", "维c", "维他", "拿铁", "美式", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴", "七欣天", "海底捞", "老乡鸡", "塔斯汀", "库迪", "绝味", "鸭脖", "鸭货", "周黑鸭", "煌上煌", "袁记云饺", "萨莉亚", "火锅", "烤肉", "烤鸭", "烧鸭", "卤鸭", "鸭肉", "麻辣烫", "披萨", "炸鸡", "汉堡", "卤味", "生蚝", "烤生蚝", "海鲜", "鱿鱼", "铁板鱿鱼", "烧烤", "夜市", "夜摊", "大排档", "小吃", "美团外卖", "饿了么"]),
            .init(category: .dining, score: 2.8, keywords: ["便利蜂", "便利店", "全家", "罗森", "711", "7-11", "美宜佳", "茶叶蛋", "饭团", "关东煮"]),
            .init(category: .shopping, score: 4.0, keywords: ["淘宝", "京东", "拼多多", "购物", "下单", "快递", "衣服", "鞋", "数码", "耳机", "手机", "电脑", "Office 365", "Microsoft 365", "Adobe订阅", "Creative Cloud", "Notion订阅", "Notion会员", "充电器", "数据线", "充电宝", "渔具", "鱼竿", "路亚", "露营", "骑行", "摄影", "相机", "镜头", "模型", "手办", "谷子", "潮玩", "吧唧", "徽章", "亚克力", "立牌", "盲盒", "泡泡玛特", "POP MART", "POPMART", "LABUBU", "棉花娃娃", "痛包", "同人本", "乙游周边", "漫展周边", "乐器", "茶具", "咖啡器具"]),
            .init(category: .daily, score: 6.4, keywords: ["奶粉", "尿不湿", "纸尿裤", "拉拉裤", "辅食", "奶瓶", "安抚奶嘴", "宝宝湿巾", "婴儿湿巾", "童装", "儿童座椅", "推车", "托育费", "托班费", "幼儿园学费", "早教课", "狗粮", "猫粮", "猫砂", "宠物粮", "宠物口粮", "尿垫", "冻干", "宠物罐头"]),
            .init(category: .daily, score: 3.0, keywords: ["超市", "日用品", "纸巾", "洗衣", "打印", "理发", "宠物", "买菜", "生鲜", "盒马", "叮咚买菜", "小象超市", "朴朴超市", "美团闪购", "京东秒送", "山姆", "山姆会员", "永辉", "永辉超市", "大润发", "钱大妈"]),
            .init(category: .daily, score: 4.6, keywords: ["纸巾", "抽纸", "卷纸", "湿巾", "洗衣液", "洗衣凝珠", "洗洁精", "垃圾袋", "清洁", "日化", "日用品", "家用", "补货", "买菜", "生鲜", "水果", "蔬菜", "肉禽", "水产", "鸡蛋", "给家补货"]),
            .init(category: .entertainment, score: 3.0, keywords: ["电影", "影院", "游戏", "网吧", "网咖", "上网费", "直播打赏", "主播打赏", "抖音打赏", "直播礼物", "B站会员", "哔哩哔哩会员", "爱奇艺会员", "腾讯视频会员", "优酷会员", "芒果TV会员", "网易云会员", "网易云音乐会员", "QQ音乐会员", "喜马拉雅会员", "百度网盘会员", "WPS会员", "iCloud订阅", "Apple Music", "演唱会", "门票"]),
            .init(category: .lodging, score: 4.0, keywords: ["酒店", "民宿", "住宿", "宾馆", "电竞酒店"]),
            .init(category: .health, score: 4.0, keywords: ["药店", "药房", "医院", "挂号", "门诊", "体检", "洗牙", "配镜", "验光", "医美", "医美脱毛", "光子嫩肤", "水光针", "健身", "健身房", "健身卡", "月卡", "年卡", "私教", "团课", "课程", "跑步", "理疗", "康复", "按摩", "补剂", "蛋白", "运动装备", "运动鞋", "运动服"]),
            .init(category: .home, score: 4.0, keywords: ["房租", "水电", "电费", "燃气", "物业", "宽带", "暖气费", "取暖费", "供暖费", "采暖费", "热力费", "供热费", "暖气缴费", "热力公司", "网上国网", "国网", "保洁", "家政", "钟点工", "开荒保洁", "上门保洁", "深度保洁", "擦玻璃", "清洗油烟机", "空调清洗", "搬家", "搬家公司", "货拉拉搬家"]),
            .init(category: .social, score: 4.0, keywords: ["红包", "礼物", "请客", "份子钱", "随礼", "探望", "白事", "白事随礼", "奠仪", "帛金", "花圈"]),
            .init(category: .other, score: 3.0, keywords: ["驾校", "驾校报名费", "驾考", "学车", "彩票", "福彩", "体彩", "刮刮乐"]),
        ],
        ocrKeywordRules: [
            .init(category: .dining, score: 4.5, keywords: ["海底捞", "老乡鸡", "塔斯汀", "库迪", "库迪咖啡", "绝味", "鸭脖", "周黑鸭", "袁记云饺", "萨莉亚", "生蚝", "烤生蚝", "海鲜", "鱿鱼", "铁板鱿鱼", "烤鸭", "烧鸭", "卤鸭", "鸭肉", "烧烤", "夜市", "大排档"]),
            .init(category: .daily, score: 3.0, keywords: ["山姆", "山姆会员", "永辉", "永辉超市", "大润发", "钱大妈"]),
            .init(category: .shopping, score: 3.8, keywords: ["Office 365", "Microsoft 365", "Adobe订阅", "Creative Cloud", "Notion订阅", "Notion会员", "充电器", "数据线", "充电宝", "谷子", "潮玩", "吧唧", "亚克力", "盲盒", "泡泡玛特", "POP MART", "POPMART", "痛包", "同人本", "乙游周边", "漫展周边"]),
            .init(category: .transport, score: 4.0, keywords: ["花小猪", "洗车", "汽车保养", "车辆保养", "保养车", "ETC", "etc", "充车", "充电桩", "电车充电"]),
            .init(category: .home, score: 4.0, keywords: ["网上国网", "国网", "暖气费", "取暖费", "供暖费", "采暖费", "热力费", "供热费", "家政", "保洁", "上门保洁", "搬家", "搬家公司", "货拉拉搬家"])
        ],
        comboRules: [
            .init(keywords: ["高铁", "机票", "机场", "车站", "返程", "出发"], scores: [.transport: 3.2, .lodging: 1.2, .entertainment: 1.0])
        ],
        emotionKeywordRules: [
            .init(id: "fitness", category: .health, keywords: ["运动", "健身", "健身房", "训练", "跑步", "瑜伽", "补给", "能量", "护具", "恢复", "锻炼", "理疗", "康复", "运动装备"]),
            .init(id: "drink", category: .dining, keywords: ["饮料", "喝的", "可乐", "雪碧", "汽水", "果汁", "茶饮", "奶茶", "咖啡", "拿铁", "美式", "冰饮", "水溶", "c100", "维C", "维c", "维他"]),
            .init(id: "transport", category: .transport, keywords: ["地铁", "公交", "打车", "出租", "网约车", "路费", "车程", "通勤", "上班", "下班", "返程", "回家"]),
            .init(id: "meal", category: .dining, keywords: ["食堂", "午餐", "午饭", "简餐", "轻食", "小食", "点心", "热饭", "外卖", "饭点", "吃一口", "夜宵", "晚饭", "早餐", "早饭", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴", "七欣天", "海底捞", "老乡鸡", "塔斯汀", "绝味", "鸭脖", "鸭货", "袁记云饺", "萨莉亚", "火锅", "烤肉", "烤鸭", "烧鸭", "卤鸭", "鸭肉", "麻辣烫", "卤味", "生蚝", "烤生蚝", "鱿鱼", "铁板鱿鱼", "烧烤", "夜市", "大排档", "便当", "盖饭"]),
            .init(id: "convenience", category: .dining, keywords: ["便利蜂", "便利店", "全家", "罗森", "711", "7-11", "美宜佳", "茶叶蛋", "饭团", "关东煮", "便当", "三明治"]),
            .init(id: "baby_supply", category: .daily, keywords: ["宝宝", "孩子", "婴儿", "奶粉", "尿不湿", "纸尿裤", "拉拉裤", "辅食", "奶瓶", "安抚奶嘴", "宝宝湿巾", "婴儿湿巾", "童装", "儿童座椅", "推车"]),
            .init(id: "pet_supply", category: .daily, keywords: ["宠物", "毛孩子", "毛孩", "狗粮", "猫粮", "猫砂", "宠物粮", "宠物口粮", "尿垫", "冻干", "罐头", "宠物罐头", "驱虫", "宠物医院", "洗护"]),
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

    static func strongManualNoteCategory(of text: String) -> HomeItem.Category? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        let matches = Set(strongManualNoteOverrideRules.compactMap { rule in
            rule.keywords.contains { normalized.contains($0.lowercased()) } ? rule.category : nil
        })
        guard matches.count == 1 else { return nil }
        return matches.first
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
        "早间一段路", "公共交通一段", "日常出行",
        "早餐先记下", "中午一顿饭", "晚饭记一笔", "认真吃一顿", "日常餐饮",
        "添置一件东西", "日常添置", "日用补齐", "日用记录",
        "一次娱乐安排", "轻量娱乐", "住宿安排", "短暂停留",
        "健康安排", "健康记录", "居家安排", "居家补给",
        "心意往来", "见面记录", "单独记录", "日常记录",
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
