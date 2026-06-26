import Foundation

enum LifeSceneKind: String, CaseIterable, Hashable {
    case breakfast
    case quickMeal
    case coffee
    case workMeal
    case commute
    case cityRoute
    case convenienceSupply
    case groceries
    case homeSupply
    case shopping
    case medicalVisit
    case medicineCare
    case fitness
    case bodyCare
    case lodging
    case social
    case leisure
    case errand
    case general
}

enum LifeSceneConfidenceTier: Int, Comparable {
    case weak = 0
    case medium = 1
    case strong = 2

    static func < (lhs: LifeSceneConfidenceTier, rhs: LifeSceneConfidenceTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct LifeSceneSignal: Equatable {
    let kind: LifeSceneKind
    let category: HomeItem.Category
    let score: Double
    let label: String
    let tag: String
    let priority: Int

    var confidenceTier: LifeSceneConfidenceTier {
        if score >= 6.6 { return .strong }
        if score >= 5.8 { return .medium }
        return .weak
    }
}

struct LifeSceneWeeklyCopy: Equatable {
    let fact: String
    let cares: [String]
    let leadingTag: String
    let semanticTag: String
    let supportTag: String?
}

enum LifeSceneSemanticService {
    static func classify(_ item: HomeItem) -> LifeSceneSignal {
        let brand = MerchantBrandCatalog.definition(for: item.merchantBrandId)
            ?? MerchantBrandCatalog.matchBrand(in: item.title)
        let text = semanticText(item: item, brand: brand)
        var candidates = signals(category: item.category, text: text, brand: brand)
        candidates.append(defaultSignal(for: item.category))
        return candidates.sorted { lhs, rhs in
            if abs(lhs.score - rhs.score) < 0.001 {
                return lhs.priority < rhs.priority
            }
            return lhs.score > rhs.score
        }.first ?? defaultSignal(for: item.category)
    }

    static func dominantScene(in items: [HomeItem]) -> (signal: LifeSceneSignal, count: Int, latest: Date)? {
        let rows = items.map { (item: $0, signal: classify($0)) }
        let grouped = Dictionary(grouping: rows, by: { $0.signal.kind })
        return grouped.compactMap { _, entries -> (signal: LifeSceneSignal, count: Int, latest: Date, score: Double)? in
            guard let strongest = entries.map({ $0.signal }).max(by: { $0.score < $1.score }) else { return nil }
            let latest = entries.map({ $0.item.createdAt }).max() ?? .distantPast
            let score = entries.reduce(0) { $0 + $1.signal.score }
            return (strongest, entries.count, latest, score)
        }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                if abs(lhs.score - rhs.score) < 0.001 {
                    return lhs.latest > rhs.latest
                }
                return lhs.score > rhs.score
            }
            return lhs.count > rhs.count
        }
        .first
        .map { ($0.signal, $0.count, $0.latest) }
    }

    static func weeklyCopy(for signal: LifeSceneSignal, count: Int) -> LifeSceneWeeklyCopy {
        switch signal.kind {
        case .breakfast:
            return LifeSceneWeeklyCopy(
                fact: "早餐记了 \(count) 次",
                cares: ["赶早也吃上一口，就很好", "早上先垫一垫，别空着出门"],
                leadingTag: "#早餐\(count)次",
                semanticTag: "#早上垫一口",
                supportTag: "#工作日前奏"
            )
        case .quickMeal:
            return LifeSceneWeeklyCopy(
                fact: "饭点外卖记了 \(count) 次",
                cares: ["忙归忙，先吃上", "饭点没有落空，也算稳住"],
                leadingTag: "#饭点\(count)次",
                semanticTag: "#饭点外卖",
                supportTag: "#热乎一口"
            )
        case .coffee:
            return LifeSceneWeeklyCopy(
                fact: "咖啡饮品记了 \(count) 次",
                cares: ["这周靠它提了几次神", "喝完这一杯，也早点睡"],
                leadingTag: "#提神\(count)次",
                semanticTag: "#咖啡续航",
                supportTag: "#忙里清醒"
            )
        case .workMeal:
            return LifeSceneWeeklyCopy(
                fact: "工作餐记了 \(count) 次",
                cares: ["忙的时候先吃上，就不算亏待自己", "工位旁边的几顿饭，也在撑住这一周"],
                leadingTag: "#工作餐\(count)次",
                semanticTag: "#饭点在忙",
                supportTag: "#先吃上"
            )
        case .commute:
            return LifeSceneWeeklyCopy(
                fact: "通勤路上记了 \(count) 笔",
                cares: ["通勤路上的时间，也算这一周的一部分", "来回跑了不少，到家先缓一缓"],
                leadingTag: "#通勤\(count)次",
                semanticTag: "#早晚路上",
                supportTag: "#工作日节奏"
            )
        case .cityRoute:
            return LifeSceneWeeklyCopy(
                fact: "出行路上记了 \(count) 笔",
                cares: ["这周跑动不少，到了就先歇口气", "每一段路记下来，回头也清楚"],
                leadingTag: "#出行\(count)次",
                semanticTag: "#出门办事",
                supportTag: "#城市里移动"
            )
        case .convenienceSupply:
            return LifeSceneWeeklyCopy(
                fact: "便利店和即时补给记了 \(count) 次",
                cares: ["这些小补给，像是在补忙碌里的缺口", "路过买点需要的，也很真实"],
                leadingTag: "#补给\(count)次",
                semanticTag: "#便利店补给",
                supportTag: "#路过带上"
            )
        case .groceries:
            return LifeSceneWeeklyCopy(
                fact: "超市买菜记了 \(count) 次",
                cares: ["把吃的备好，忙起来也少点乱", "厨房有东西，吃饭就不慌"],
                leadingTag: "#买菜\(count)次",
                semanticTag: "#超市买菜",
                supportTag: "#给家补货"
            )
        case .homeSupply:
            return LifeSceneWeeklyCopy(
                fact: "家用补给记了 \(count) 次",
                cares: ["缺的东西补上了，家里会顺一点", "这些小补给，确实会用得上"],
                leadingTag: "#家用\(count)次",
                semanticTag: "#家用补货",
                supportTag: "#日常运转"
            )
        case .shopping:
            return LifeSceneWeeklyCopy(
                fact: "网购添置记了 \(count) 笔",
                cares: ["买到需要的就好", "兴趣里的小投入，也会留下生活形状"],
                leadingTag: "#网购\(count)笔",
                semanticTag: "#快递到了",
                supportTag: "#兴趣装备"
            )
        case .medicalVisit:
            return LifeSceneWeeklyCopy(
                fact: "就医检查记了 \(count) 笔",
                cares: ["检查和问诊跑起来也费时间，今天先缓一缓", "身体的事先处理好，别拖着"],
                leadingTag: "#就医\(count)笔",
                semanticTag: "#身体这边",
                supportTag: "#别急着恢复"
            )
        case .medicineCare:
            return LifeSceneWeeklyCopy(
                fact: "用药护理记了 \(count) 笔",
                cares: ["药和护理记清楚，后面少一点乱", "小不舒服先处理掉，别拖着"],
                leadingTag: "#护理\(count)笔",
                semanticTag: "#用药护理",
                supportTag: "#身体事项"
            )
        case .fitness:
            return LifeSceneWeeklyCopy(
                fact: "锻炼安排记了 \(count) 次",
                cares: ["能动起来已经很好，别忘了休息", "保持住就好，不用每次都拉满"],
                leadingTag: "#锻炼\(count)次",
                semanticTag: "#健身恢复",
                supportTag: "#记得休息"
            )
        case .bodyCare:
            return LifeSceneWeeklyCopy(
                fact: "身体护理记了 \(count) 笔",
                cares: ["小问题先处理掉，日子会轻一点", "把护理安排好，后面少一点乱"],
                leadingTag: "#身体护理\(count)笔",
                semanticTag: "#身体事项",
                supportTag: "#留点恢复时间"
            )
        case .lodging:
            return LifeSceneWeeklyCopy(
                fact: "停留和住宿记了 \(count) 笔",
                cares: ["在外面也要睡踏实", "换个地方停下，也算这周的一段"],
                leadingTag: "#停留\(count)笔",
                semanticTag: "#落脚",
                supportTag: "#在外面"
            )
        case .social:
            return LifeSceneWeeklyCopy(
                fact: "人情往来记了 \(count) 笔",
                cares: ["见面和心意，都先记一笔", "这些来往，回头看会有用"],
                leadingTag: "#人情\(count)笔",
                semanticTag: "#见面和心意",
                supportTag: "#有来有往"
            )
        case .leisure:
            return LifeSceneWeeklyCopy(
                fact: "放松安排记了 \(count) 次",
                cares: ["该放松就放松", "这周也需要一点喘气的时间"],
                leadingTag: "#放松\(count)次",
                semanticTag: "#喘口气",
                supportTag: "#留点余地"
            )
        case .errand:
            return LifeSceneWeeklyCopy(
                fact: "临时事务记了 \(count) 笔",
                cares: ["这些小事处理掉，日子会顺一点", "不显眼的小事，也占这一周的精力"],
                leadingTag: "#办事\(count)笔",
                semanticTag: "#临时处理",
                supportTag: "#生活小修补"
            )
        case .general:
            return LifeSceneWeeklyCopy(
                fact: "\(signal.label)记了 \(count) 次",
                cares: ["先这样留着，之后再看会更清楚", "说不清也没关系，先记下来"],
                leadingTag: "#\(signal.label)\(count)次",
                semanticTag: signal.tag,
                supportTag: "#生活线索"
            )
        }
    }

    static func memoryLine(for signal: LifeSceneSignal, count: Int) -> String {
        let copy = weeklyCopy(for: signal, count: count)
        guard let care = copy.cares.first, !care.isEmpty else {
            return copy.fact
        }
        return "\(copy.fact)，\(care)"
    }

    static func displayTheme(for signal: LifeSceneSignal) -> String {
        let copy = weeklyCopy(for: signal, count: 1)
        return copy.semanticTag.replacingOccurrences(of: "#", with: "")
    }

    static func noteSuggestion(for signal: LifeSceneSignal, amount: Double, date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch signal.kind {
        case .breakfast:
            return hour < 10 ? "早餐路上买一口" : "早餐补给记一笔"
        case .quickMeal:
            if (11..<14).contains(hour) { return "午餐简餐记一笔" }
            if (17..<21).contains(hour) { return "晚饭简餐记一笔" }
            return "饭点外卖记一笔"
        case .coffee:
            return "咖啡饮品记一笔"
        case .workMeal:
            return "工作餐吃饭记一笔"
        case .commute:
            return hour < 12 ? "早高峰通勤一段" : "通勤路上记一笔"
        case .cityRoute:
            return amount <= 20 ? "短途出行记一笔" : "出门这一趟记一笔"
        case .convenienceSupply:
            return "便利店补给记一笔"
        case .groceries:
            return "超市买菜记一笔"
        case .homeSupply:
            return "家用补给记一笔"
        case .shopping:
            return "网购添置记一笔"
        case .medicalVisit:
            return "就医检查记一笔"
        case .medicineCare:
            return "用药护理记一笔"
        case .fitness:
            return "锻炼运动记一笔"
        case .bodyCare:
            return "身体护理记一笔"
        case .lodging:
            return "住宿停留记一笔"
        case .social:
            return "人情往来记一笔"
        case .leisure:
            return "放松娱乐记一笔"
        case .errand:
            return "临时办事记一笔"
        case .general:
            return "\(signal.label)记一笔"
        }
    }

    private static func semanticText(item: HomeItem, brand: MerchantBrandDefinition?) -> String {
        [
            item.title,
            item.displayEmotionTag,
            item.category.rawValue,
            brand?.displayName ?? "",
            brand?.id ?? ""
        ]
        .joined(separator: " ")
        .lowercased()
    }

    private static func signals(
        category: HomeItem.Category,
        text: String,
        brand: MerchantBrandDefinition?
    ) -> [LifeSceneSignal] {
        var result: [LifeSceneSignal] = []
        func add(_ kind: LifeSceneKind, _ score: Double, _ category: HomeItem.Category, _ label: String, _ tag: String, _ priority: Int) {
            result.append(LifeSceneSignal(kind: kind, category: category, score: score, label: label, tag: tag, priority: priority))
        }

        switch brand?.id {
        case "luckin", "starbucks", "manner", "mixue", "heytea", "naixue", "cotti":
            add(.coffee, 7.0, .dining, "咖啡饮品", "#提神", 10)
        case "meituan", "eleme", "mcdonalds", "kfc", "qixintian", "haidilao", "laoxiangji", "tastien", "juewei", "yuanjiyunjiao", "saizeriya":
            add(.quickMeal, 6.6, .dining, "饭点外卖", "#饭点外卖", 20)
        case "metro_transit":
            add(.commute, 7.2, .transport, "通勤", "#通勤", 5)
        case "didi", "huaxiaozhu", "alipay_ride":
            add(.cityRoute, 6.8, .transport, "出行", "#出门办事", 18)
        case "familymart", "lawson", "bianlifeng", "seveneleven", "meiyijia":
            add(.convenienceSupply, 6.8, .daily, "便利店补给", "#便利店", 25)
        case "freshippo", "dingdong", "xiaoxiang", "meituan_grocery", "pupu", "samsclub", "yonghui", "rtmart", "qiandama":
            add(.groceries, 6.8, .daily, "超市买菜", "#超市买菜", 30)
        case "sgcc_online":
            add(.homeSupply, 6.7, .home, "居家账单", "#居家账单", 34)
        case "taobao", "jd", "miniso":
            add(.shopping, 6.4, .shopping, "网购添置", "#快递到了", 45)
        default:
            break
        }

        if containsAny(text, ["早餐", "早饭", "豆浆", "包子", "饭团", "早班", "上班前"]) {
            add(.breakfast, 7.4, .dining, "早餐", "#早餐", 1)
        }
        if containsAny(text, ["食堂", "工位", "工作餐", "加班餐", "公司楼下", "单位食堂"]) {
            add(.workMeal, 7.0, .dining, "工作餐", "#工作餐", 12)
        }
        if containsAny(text, ["午餐", "午饭", "晚餐", "晚饭", "外卖", "简餐", "热饭", "吃一口", "饭点", "夜宵", "面", "粉", "馄饨", "盖饭", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴", "七欣天", "海底捞", "老乡鸡", "塔斯汀", "绝味", "袁记云饺", "萨莉亚", "火锅", "烤肉", "麻辣烫", "披萨", "炸鸡", "汉堡", "卤味", "便当"]) {
            add(.quickMeal, 6.2, .dining, "饭点外卖", "#饭点外卖", 22)
        }
        if containsAny(text, ["咖啡", "拿铁", "美式", "奶茶", "饮品", "茶饮", "提神", "库迪"]) {
            add(.coffee, 6.8, .dining, "咖啡饮品", "#提神", 15)
        }
        if containsAny(text, ["上班", "下班", "到岗", "通勤", "早高峰", "晚高峰", "地铁", "公交", "轨道交通"]) {
            add(.commute, 7.0, .transport, "通勤", "#通勤", 6)
        }
        if containsAny(text, ["打车", "出租", "网约车", "滴滴", "花小猪", "单车", "骑车", "停车", "洗车", "汽车保养", "车辆保养", "保养车", "etc", "ETC", "车票", "高铁", "火车", "机场", "航班", "过路费", "路费", "充车", "充电桩", "电车充电", "汽车充电", "车辆充电", "新能源充电", "补能"]) {
            add(.cityRoute, 6.4, .transport, "出行", "#出门办事", 19)
        }
        if containsAny(text, ["便利蜂", "便利店", "全家", "罗森", "7-11", "711", "美宜佳", "茶叶蛋", "饭团", "关东煮", "小食"]) {
            add(.convenienceSupply, 6.6, .daily, "便利店补给", "#便利店", 26)
        }
        if containsAny(text, ["买菜", "食材", "盒马", "叮咚", "小象超市", "京东到家", "京东秒送", "朴朴", "山姆", "山姆会员", "永辉", "永辉超市", "大润发", "钱大妈", "菜场", "水果", "厨房", "饭桌", "生鲜", "蔬菜", "鸡蛋", "淘宝买菜", "美团买菜", "牛奶", "鲜奶", "纯牛奶", "酸奶", "认养一头牛", "特仑苏", "伊利", "蒙牛", "光明", "金典", "简爱", "悦鲜活", "奶粉"]) {
            add(.groceries, 6.6, .daily, "超市买菜", "#超市买菜", 31)
        }
        if containsAny(text, ["纸巾", "洗衣液", "洗洁精", "清洁", "垃圾袋", "洗发水", "沐浴露", "牙刷", "毛巾", "美团闪购", "即时零售", "给家补货"]) {
            add(.homeSupply, 6.1, .daily, "家用补给", "#家用补给", 36)
        }
        if containsAny(text, ["保洁", "家政", "钟点工", "开荒保洁", "上门保洁", "深度保洁", "擦玻璃", "清洗油烟机", "空调清洗", "搬家", "搬家公司", "货拉拉搬家", "网上国网", "国网", "暖气费", "取暖费", "供暖费", "采暖费", "热力费", "供热费", "暖气缴费", "热力公司", "水费", "电费", "燃气", "物业", "宽带"]) {
            add(.homeSupply, 6.5, .home, "居家账单", "#居家安排", 35)
        }
        if containsAny(text, ["宝宝", "孩子", "婴儿", "奶粉", "尿不湿", "纸尿裤", "拉拉裤", "辅食", "奶瓶", "安抚奶嘴", "宝宝湿巾", "婴儿湿巾", "童装", "儿童座椅", "推车", "托育费", "托班费", "幼儿园学费", "早教课", "宠物", "毛孩子", "毛孩", "狗粮", "猫粮", "猫砂", "宠物粮", "宠物口粮", "尿垫", "冻干", "宠物罐头", "驱虫", "宠物医院", "洗护"]) {
            add(.homeSupply, 6.9, .daily, "家庭照护", "#照护补给", 13)
        }
        if containsAny(text, ["打印", "复印", "证件照", "配钥匙", "钥匙", "修锁", "手续费", "服务费", "押金"]) {
            add(.errand, 6.0, .other, "临时事务", "#临时处理", 38)
        }
        if containsAny(text, ["Office 365", "Microsoft 365", "Adobe订阅", "Creative Cloud", "Notion订阅", "Notion会员"]) {
            add(.shopping, 6.3, .shopping, "数字服务", "#数字订阅", 45)
        }
        if containsAny(text, ["淘宝", "京东", "拼多多", "购物", "下单", "快递", "衣服", "鞋", "护肤", "充电器", "数据线", "充电宝", "耳机", "手机", "文具", "渔具", "鱼竿", "路亚", "露营", "骑行", "摄影", "相机", "镜头", "模型", "手办", "谷子", "潮玩", "吧唧", "徽章", "亚克力", "立牌", "盲盒", "泡泡玛特", "POP MART", "POPMART", "LABUBU", "棉花娃娃", "痛包", "同人本", "乙游周边", "漫展周边", "乐器", "茶具", "咖啡器具"]) {
            add(.shopping, 6.1, .shopping, "网购添置", "#快递到了", 46)
        }
        if containsAny(text, ["医院", "门诊", "诊所", "挂号", "问诊", "体检", "检查", "拍片", "验血", "口腔", "牙科", "洗牙", "配镜", "验光", "医美", "医美脱毛", "光子嫩肤", "水光针"]) {
            add(.medicalVisit, 7.4, .health, "就医检查", "#就医", 2)
        }
        if containsAny(text, ["药店", "药房", "买药", "用药", "感冒", "退烧", "消炎", "止痛", "维生素", "眼药水", "创可贴"]) {
            add(.medicineCare, 7.0, .health, "用药护理", "#用药护理", 8)
        }
        if containsAny(text, ["健身", "健身卡", "月卡", "年卡", "私教", "团课", "跑步", "瑜伽", "运动", "训练", "球场", "游泳", "课程", "锻炼"]) {
            add(.fitness, 6.8, .health, "锻炼", "#锻炼", 14)
        }
        if containsAny(text, ["按摩", "理疗", "康复", "护具", "筋膜", "贴膏", "膏药", "护理"]) {
            add(.bodyCare, 6.5, .health, "身体护理", "#身体护理", 16)
        }
        if containsAny(text, ["酒店", "宾馆", "民宿", "住宿", "客栈", "电竞酒店", "房费", "续住"]) {
            add(.lodging, 6.6, .lodging, "停留住宿", "#住宿", 50)
        }
        if containsAny(text, ["红包", "礼物", "送礼", "份子", "随礼", "生日", "探望", "拜访", "请客", "聚餐", "朋友", "白事", "白事随礼", "奠仪", "帛金", "花圈"]) {
            add(.social, 6.3, .social, "人情往来", "#人情", 55)
        }
        if containsAny(text, ["电影", "影院", "游戏", "网吧", "网咖", "上网费", "直播打赏", "主播打赏", "抖音打赏", "直播礼物", "B站会员", "哔哩哔哩会员", "爱奇艺会员", "腾讯视频会员", "优酷会员", "芒果TV会员", "网易云会员", "网易云音乐会员", "QQ音乐会员", "喜马拉雅会员", "百度网盘会员", "WPS会员", "iCloud订阅", "Apple Music", "演唱会", "音乐节", "剧场", "展", "博物馆", "ktv", "唱歌", "桌游"]) {
            add(.leisure, 6.1, .entertainment, "放松安排", "#放松", 60)
        }
        if containsAny(text, ["驾校", "驾校报名费", "驾考", "学车", "彩票", "福彩", "体彩", "刮刮乐"]) {
            add(.errand, 5.8, .other, "临时事务", "#临时处理", 65)
        }

        if result.isEmpty {
            let fallback = defaultSignal(for: category)
            result.append(fallback)
        }
        return result
    }

    private static func defaultSignal(for category: HomeItem.Category) -> LifeSceneSignal {
        switch category {
        case .dining:
            return LifeSceneSignal(kind: .quickMeal, category: .dining, score: 2.4, label: "吃饭", tag: "#吃饭", priority: 80)
        case .transport:
            return LifeSceneSignal(kind: .cityRoute, category: .transport, score: 2.4, label: "出行", tag: "#出行", priority: 80)
        case .shopping:
            return LifeSceneSignal(kind: .shopping, category: .shopping, score: 2.2, label: "网购添置", tag: "#快递到了", priority: 80)
        case .daily:
            return LifeSceneSignal(kind: .homeSupply, category: .daily, score: 2.2, label: "家用补给", tag: "#家用补货", priority: 80)
        case .entertainment:
            return LifeSceneSignal(kind: .leisure, category: .entertainment, score: 2.2, label: "放松安排", tag: "#放松", priority: 80)
        case .lodging:
            return LifeSceneSignal(kind: .lodging, category: .lodging, score: 2.2, label: "停留住宿", tag: "#住宿", priority: 80)
        case .health:
            return LifeSceneSignal(kind: .bodyCare, category: .health, score: 2.3, label: "健康相关", tag: "#健康", priority: 80)
        case .home:
            return LifeSceneSignal(kind: .homeSupply, category: .home, score: 2.2, label: "家里的事", tag: "#居家", priority: 80)
        case .social:
            return LifeSceneSignal(kind: .social, category: .social, score: 2.2, label: "人情往来", tag: "#人情", priority: 80)
        case .other:
            return LifeSceneSignal(kind: .errand, category: .other, score: 1.8, label: "临时事务", tag: "#临时处理", priority: 80)
        }
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }
}
