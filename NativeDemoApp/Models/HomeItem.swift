import Foundation

struct HomeItem: Identifiable, Codable, Equatable {
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
        categoryCorrectionFrom: Category? = nil
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
        if let refined = Self.refinedEmotionTag(title: title, category: category, amount: amount, date: createdAt),
           Self.shouldPreferRefinedTag(current: trimmed, refined: refined) {
            return refined
        }
        return trimmed
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
            if containsAny(text, ["药", "药店", "感冒", "退烧", "消炎", "止痛", "维生素", "眼药水", "创可贴"]) {
                return "药品护理记下"
            }
            if containsAny(text, ["按摩", "理疗", "康复", "护具", "筋膜", "贴膏", "膏药", "蛋白", "补剂", "能量胶"]) {
                return "恢复护理安排"
            }
        case .dining:
            if containsAny(text, ["夜宵", "深夜", "夜里", "凌晨"]) { return "夜里补一点" }
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
            if containsAny(text, ["午餐", "午饭", "中午"]) { return "中午一顿饭" }
            if containsAny(text, ["晚餐", "晚饭"]) { return "晚饭时间坐一会儿" }
            if containsAny(text, ["咖啡", "拿铁", "美式", "奶茶", "饮品", "茶"]) { return "买杯喝的" }
            if containsAny(text, ["火锅", "烤肉", "烧烤", "串串"]) { return "认真吃一顿" }
            if containsAny(text, ["面", "粉", "馄饨", "饺子", "盖饭", "米线", "麻辣烫"]) { return "热乎一碗记下" }
            if containsAny(text, ["甜品", "蛋糕", "面包", "冰淇淋", "冰粉", "糖水"]) { return "给今天一点甜" }
            if containsAny(text, ["水果", "酸奶", "轻食", "沙拉"]) { return "轻轻补一点" }
            if containsAny(text, ["买菜", "菜场", "生鲜", "超市菜"]) { return "回家做饭的料" }
        case .transport:
            if containsAny(text, ["停车", "停车费", "车位"]) { return "车停稳了" }
            if containsAny(text, ["加油", "油费", "充电", "充电桩"]) { return "给车补点能量" }
            if containsAny(text, ["打车", "出租", "网约车", "滴滴"]) { return "打车这一程" }
            if containsAny(text, ["地铁", "公交", "巴士"]) { return "公共交通一段" }
            if containsAny(text, ["共享单车", "单车", "骑车", "电动车"]) { return "短短骑一程" }
            if containsAny(text, ["高铁", "火车", "动车", "车票"]) { return "远一点的路" }
            if containsAny(text, ["机票", "机场", "航班"]) { return "飞一程记下" }
            if containsAny(text, ["高速", "过路费", "etc"]) { return "路上通行一笔" }
        case .shopping:
            if containsAny(text, ["衣服", "上衣", "裤子", "裙", "外套", "内衣"]) { return "给衣柜添一件" }
            if containsAny(text, ["鞋", "袜"]) { return "脚下换新一点" }
            if containsAny(text, ["护肤", "洗面奶", "面霜", "防晒", "口红", "化妆"]) { return "照顾自己一点" }
            if containsAny(text, ["手机", "耳机", "充电器", "数据线", "电脑", "键盘"]) { return "数码小物到位" }
            if containsAny(text, ["书", "文具", "本子", "笔"]) { return "书桌添点东西" }
            if containsAny(text, ["花", "香薰", "摆件"]) { return "给日子添点好看" }
            if containsAny(text, ["快递", "运费"]) { return "路上的小费用" }
        case .daily:
            if containsAny(text, ["纸巾", "卷纸", "抽纸", "湿巾"]) { return "纸品补上了" }
            if containsAny(text, ["洗衣液", "洗洁精", "清洁", "垃圾袋", "消毒"]) { return "清洁用品补齐" }
            if containsAny(text, ["洗发水", "沐浴露", "牙刷", "毛巾"]) { return "洗护日常补上" }
            if containsAny(text, ["理发", "剪发", "洗剪吹"]) { return "头发清爽一下" }
            if containsAny(text, ["打印", "复印", "证件照", "照片"]) { return "临时办点事" }
            if containsAny(text, ["钥匙", "配钥匙", "锁"]) { return "生活小修补" }
            if containsAny(text, ["雨伞", "伞"]) { return "给天气留个准备" }
        case .entertainment:
            if containsAny(text, ["电影", "影院"]) { return "看场电影" }
            if containsAny(text, ["游戏", "点券", "皮肤", "会员"]) { return "娱乐里充一笔" }
            if containsAny(text, ["演唱会", "音乐节", "live", "话剧", "剧场"]) { return "看一场现场" }
            if containsAny(text, ["展", "博物馆", "美术馆"]) { return "出去看点东西" }
            if containsAny(text, ["ktv", "唱歌"]) { return "唱一会儿" }
            if containsAny(text, ["桌游", "密室", "剧本杀"]) { return "和人玩一局" }
        case .lodging:
            if containsAny(text, ["酒店", "宾馆"]) { return "住一晚记下" }
            if containsAny(text, ["民宿", "客栈"]) { return "今晚落脚这里" }
            if containsAny(text, ["房费", "续住", "押金"]) { return "住宿安排一笔" }
        case .home:
            if containsAny(text, ["房租", "租金"]) { return "住处安稳下来" }
            if containsAny(text, ["水费", "电费", "燃气", "煤气"]) { return "家里运转一笔" }
            if containsAny(text, ["物业", "宽带", "网费"]) { return "居家固定支出" }
            if containsAny(text, ["维修", "修理", "师傅", "换锁", "疏通"]) { return "家里修一处" }
            if containsAny(text, ["锅", "碗", "厨房", "床品", "收纳", "灯"]) { return "给家添点方便" }
            if containsAny(text, ["冰箱", "洗衣机", "空调", "家电"]) { return "家电安排一笔" }
        case .social:
            if containsAny(text, ["礼物", "送礼", "伴手礼"]) { return "带点心意" }
            if containsAny(text, ["红包", "份子", "随礼"]) { return "人情往来一笔" }
            if containsAny(text, ["生日", "蛋糕"]) { return "生日里的心意" }
            if containsAny(text, ["婚礼", "满月", "乔迁"]) { return "重要日子记下" }
            if containsAny(text, ["探望", "看望", "拜访"]) { return "去见挂念的人" }
            if containsAny(text, ["请客", "聚餐", "朋友"]) { return "见面吃一顿" }
        case .other:
            if containsAny(text, ["打印", "复印", "证件照"]) { return "临时办点事" }
            if containsAny(text, ["押金", "保证金"]) { return "先垫一笔" }
            if containsAny(text, ["手续费", "服务费"]) { return "小费用记下" }
            if containsAny(text, ["罚款", "违章"]) { return "不太想记也记下" }
        }

        return nil
    }

    private static func shouldPreferRefinedTag(current: String, refined: String) -> Bool {
        guard current != refined else { return false }
        let genericExact = [
            "健康记录", "健康支出", "健康相关一笔", "身体相关大笔支出", "身体项目记清楚",
            "身体提醒先记下", "基础护理用品", "今天的护理记录", "身体小用品", "健康小物补齐",
            "运动后买点恢复用品", "运动恢复用品补齐", "运动后补给", "训练恢复补给",
            "运动小补给", "身体恢复安排", "给身体一点照顾", "今天的运动安排",
            "日常餐饮", "认真吃了一顿", "去远一点", "日常出行", "计划内添置", "日常添置",
            "日用补齐", "日用记录", "一次娱乐安排", "轻量娱乐", "住宿安排", "短暂停留",
            "居家安排", "居家补给", "人情往来", "见面记录", "单独记录", "日常记录"
        ]
        if genericExact.contains(current) { return true }
        let genericFragments = ["恢复用品", "恢复补给", "健康相关", "身体相关", "护理用品", "日常记录"]
        return genericFragments.contains { current.contains($0) }
    }

    private static func containsTravelKeyword(_ text: String) -> Bool {
        let keywords = ["旅行", "旅途", "景区", "景点", "行程", "酒店", "民宿", "住宿", "机票", "高铁", "机场", "返程", "摆渡"]
        return keywords.contains { text.contains($0) }
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
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
        case id, title, amount, category, source, createdAt, updatedAt, emotionTag, merchantBrandId, draftMeta, userEditedTitle, userEditedCategory, categoryCorrectionFrom
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
