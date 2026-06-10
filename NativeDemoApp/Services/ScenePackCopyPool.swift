import Foundation

struct ScenePackTier {
    let maxAmount: Double
    let notes: [String]
}

struct ScenePackDefinition {
    let id: String
    let emoji: String
    let label: String
    let desc: String
    let category: HomeItem.Category
    let tiers: [ScenePackTier]
}

enum ScenePackCopyPool {
    static let definitions: [ScenePackDefinition] = [
        ScenePackDefinition(
            id: "commute",
            emoji: "🚇",
            label: "打工人通勤包",
            desc: "把通勤记成日常一句",
            category: .transport,
            tiers: [
                ScenePackTier(maxAmount: 5, notes: ["日常地铁通勤出行", "公交短途出行打卡", "一段公共交通", "早班地铁到岗", "换乘通勤完成", "今天的路费", "刷卡进站，出发", "短途公交到家"]),
                ScenePackTier(maxAmount: 15, notes: ["公交+地铁组合通勤", "下班高峰一段路", "打车到地铁站接驳", "通勤路上买瓶水", "今日出行主打省心", "固定路线，熟悉的感觉", "早晚通勤各记一笔", "城市穿梭的一段路"]),
                ScenePackTier(maxAmount: 30, notes: ["雨天打车通勤", "加班后打车回家", "共享单车月卡里的一天", "停车/充电小费用", "今天路程稍长一点", "通勤多花了一点时间换舒适", "早晚两次出行", "为一程准时到达"]),
                ScenePackTier(maxAmount: 9_999, notes: ["跨区通勤长途费", "出差市内交通", "高速/长途客车费", "一次较长的通勤路", "今天跑了不少路", "行程较满的一天路", "远距离往返", "为工作跑了不少路"]),
            ]
        ),
        ScenePackDefinition(
            id: "food",
            emoji: "🍵",
            label: "吃货专属包",
            desc: "吃喝里的一小句生活",
            category: .dining,
            tiers: [
                ScenePackTier(maxAmount: 15, notes: ["晨间咖啡", "简单饮品", "早餐小食", "豆浆包子早餐组合", "午前一杯奶茶", "便利店轻食补给", "早茶点心小份", "上班前快速吃一口"]),
                ScenePackTier(maxAmount: 25, notes: ["工作日午餐简餐", "外卖点到工位", "食堂一份热乎饭", "下午茶小点心", "约同事一起简吃", "饱腹又不折腾的一顿", "忙里喝点什么", "中午一顿饭"]),
                ScenePackTier(maxAmount: 40, notes: ["晚餐小聚一份主菜", "周末早午餐", "尝试一家新店", "买菜顺路带点卤味", "做了一顿家常饭", "一顿想吃的饭", "热腾腾的面或饭", "今天这顿记下"]),
                ScenePackTier(maxAmount: 9_999, notes: ["朋友小聚聚餐", "生日月小小庆祝餐", "想吃了很久的一顿", "节日加菜", "家庭聚餐贡献一道", "品质好一点的一餐", "约会餐厅体验", "美食探店打卡"]),
            ]
        ),
        ScenePackDefinition(
            id: "care",
            emoji: "💊",
            label: "照顾自己包",
            desc: "把身体的小照顾记下来",
            category: .health,
            tiers: [
                ScenePackTier(maxAmount: 20, notes: ["药店补一盒常备药", "日常护理小物", "一支眼药水", "维生素或小药片", "创可贴和棉签备一点", "小不舒服先记下", "身体小用品", "健康小物补齐"]),
                ScenePackTier(maxAmount: 60, notes: ["药店买药", "挂号问诊的一次记录", "换季护理用品补上", "牙膏牙线和口腔护理", "运动后买点恢复用品", "身体提醒先记下", "基础护理用品", "小病小痛记下"]),
                ScenePackTier(maxAmount: 200, notes: ["一次检查", "牙科护理的一段记录", "理疗/康复一次", "体检项目先记下来", "身体项目记清楚", "健康相关一笔", "问诊和用药都记清楚", "今天的护理记录"]),
                ScenePackTier(maxAmount: 9_999, notes: ["体检套餐", "牙科治疗的一笔重要开销", "医院检查与治疗相关", "长期护理用品一次补齐", "恢复相关安排", "健康大项记下", "身体相关大笔支出", "长期护理安排"]),
            ]
        ),
        ScenePackDefinition(
            id: "home",
            emoji: "🏠",
            label: "居家安顿包",
            desc: "家里的日常，也是一段生活",
            category: .home,
            tiers: [
                ScenePackTier(maxAmount: 20, notes: ["家里补个小物件", "厨房小用品补上", "一卷纸巾", "清洁小物", "给家添一点方便", "小修小补", "生活角落补齐一点", "家里的小消耗"]),
                ScenePackTier(maxAmount: 80, notes: ["日化清洁用品补货", "水电燃气的一笔日常", "家里实用小物", "宽带/话费这类日常", "厨房和卫生间补给", "家里运转的小日常", "日子里的小维护", "居家小补给"]),
                ScenePackTier(maxAmount: 300, notes: ["家电小维修记一笔", "物业/宽带相关日常", "给房间添一件东西", "床品收纳换新一点", "家里需要的东西补齐", "居住相关安排", "家里收拾一处", "这笔留给住处"]),
                ScenePackTier(maxAmount: 9_999, notes: ["房租与押金", "大件家电或家具添置", "搬家相关安排", "家里维修的一笔大项", "长期居住安排", "家的基础支出", "住处安稳下来", "为家安排的一笔"]),
            ]
        ),
        ScenePackDefinition(
            id: "social",
            emoji: "🎁",
            label: "心意往来包",
            desc: "关系里的一小句记录",
            category: .social,
            tiers: [
                ScenePackTier(maxAmount: 30, notes: ["顺路带了点小心意", "咖啡时间叙旧", "给这次见面留一句", "小小心意记下", "路过时想起了对方", "一起坐坐的小记录", "带点东西去见面", "日常往来一笔"]),
                ScenePackTier(maxAmount: 100, notes: ["聚会里的一段热闹", "请一顿饭叙旧", "节日里带份小礼", "同事小聚记一笔", "和朋友见面的一刻", "这次相聚留下来", "一顿饭里的熟悉感", "关系里的一点往来"]),
                ScenePackTier(maxAmount: 300, notes: ["探望时带了份心意", "家庭聚餐的一点贡献", "一次相聚记下", "重要日子里见一面", "给牵挂的人添点东西", "团圆时刻的一笔记录", "赴约的一段记忆", "这次见面记下"]),
                ScenePackTier(maxAmount: 9_999, notes: ["为一次重要相聚安排", "长途探望的一段记录", "重要仪式里的陪伴", "把这份记挂郑重记下", "为团圆多安排一点", "这一程是为了见面", "关系里的重要时刻", "给牵挂留下一笔温度"]),
            ]
        ),
        ScenePackDefinition(
            id: "shopping",
            emoji: "🛍️",
            label: "日常添置包",
            desc: "把常用物品记清楚",
            category: .shopping,
            tiers: [
                ScenePackTier(maxAmount: 30, notes: ["买个小物件", "给日常添一点方便", "看到合适的小东西", "小补给记一下", "刚好需要，就带回来了", "一点新鲜感", "给自己添个小物", "今天的小添置"]),
                ScenePackTier(maxAmount: 100, notes: ["补一件常用小物", "买到一件刚好需要的东西", "日常用品补齐", "日常质感小物", "这件小东西挺实用", "逛到合适的就带回家", "最近需要的一件", "把需要的东西安排上"]),
                ScenePackTier(maxAmount: 300, notes: ["挑了一件喜欢的", "给自己添一件好用的东西", "换新一件常用物", "这笔让日常方便一点", "计划里的小升级", "把想买的那件拿下", "今天买到一件合适的", "给日常添点舒服感"]),
                ScenePackTier(maxAmount: 9_999, notes: ["入手一件大件好物", "长期使用的一次升级", "选过的一笔添置", "这件会用一阵子", "把心里惦记的东西带回来", "一次比较正式的换新", "为接下来添一份便利", "一个重要物件"]),
            ]
        ),
        ScenePackDefinition(
            id: "travel",
            emoji: "✈️",
            label: "旅行出发包",
            desc: "路上的花费，也留一句",
            category: .transport,
            tiers: [
                ScenePackTier(maxAmount: 20, notes: ["短途出行小消费", "沿途小吃简单打卡", "出行便携物资采购", "景点门口一瓶水", "小城漫步小花费", "街边明信片或小挂件", "公交日票/景区摆渡", "旅途中的轻量补给"]),
                ScenePackTier(maxAmount: 80, notes: ["展馆/景点门票", "民宿小用品补买", "旅途一顿特色简餐", "城市漫步咖啡歇脚", "伴手礼试吃装", "租车/骑行小时费", "行程里的一笔小惊喜", "路边摊体验打卡"]),
                ScenePackTier(maxAmount: 200, notes: ["经济型住宿这一晚", "城际大巴/高铁一段", "特色餐厅体验", "博物馆联票", "旅行装备小升级", "行程中较充实的一天", "小镇住宿加早午餐", "为风景多走一段路"]),
                ScenePackTier(maxAmount: 9_999, notes: ["机票/高铁主段", "途中连住两晚", "行程里的重头戏", "目的地一日游团", "行李箱/装备购置", "长假出行大项", "带家人出门的一程", "一次出发记下"]),
            ]
        ),
        ScenePackDefinition(
            id: "pet",
            emoji: "🐱",
            label: "铲屎官宠物包",
            desc: "{petName} 相关的小日常",
            category: .daily,
            tiers: [
                ScenePackTier(maxAmount: 20, notes: ["给{petName}买了小零食", "给{petName}买点小点心", "补货宠物消耗小用品", "囤一包冻干", "给{petName}挑个小玩具", "猫砂/尿垫补货", "给{petName}加一罐罐头", "毛孩的小零食时间"]),
                ScenePackTier(maxAmount: 60, notes: ["为{petName}购置口粮用品", "给{petName}囤上罐头", "入手小玩具", "宠物洗护用品补货", "给{petName}买新碗新窝配件", "驱虫药常备补货", "毛孩营养膏一支", "给{petName}添件用品"]),
                ScenePackTier(maxAmount: 150, notes: ["购入{petName}专用主食与冻干", "安排{petName}日常驱虫护理", "带{petName}洗护美容，清爽干净", "宠物医院常规检查", "换季毛发护理记一笔", "给{petName}升级主食粮", "宠物保险/会员续费", "大件猫爬架小分期"]),
                ScenePackTier(maxAmount: 9_999, notes: ["带{petName}体检接种疫苗", "添置居家小窝与攀爬家具", "{petName}就医护理认真记下", "为{petName}选购高端营养口粮", "宠物手术/治疗相关", "长途托运或寄养费用", "给{petName}安排年度体检套餐", "毛孩的大件生活升级"]),
            ]
        ),
    ]

    static func note(
        for pack: ScenePackDefinition,
        amount: Double,
        date: Date = Date(),
        categoryContext: HomeItem.Category,
        petName: String,
        historyItems: [HomeItem],
        allowPetCopy: Bool = true,
        variant: Int = 0,
        allowTravelSpecificCopy: Bool = false
    ) -> String {
        let tierIndex = tierIndex(for: pack, amount: amount)
        let tier = pack.tiers[tierIndex]
        let context = contextualNotes(
            for: pack,
            category: categoryContext,
            date: date,
            allowTravelSpecificCopy: allowTravelSpecificCopy
        )
        let notes = context?.notes ?? tier.notes
        let baseSeed = "\(dayKey(for: date))|\(pack.id)|\(tierIndex)|\(categoryContext.rawValue)|\(context?.key ?? "tier")"
        let baseIndex = stableIndex(seed: baseSeed, count: notes.count)
        let index = (baseIndex + max(0, variant)) % max(1, notes.count)
        let rendered = renderPetName(notes[index], petName: petName)
        return enrichNoteWithHistory(
            rendered,
            category: categoryContext,
            date: date,
            items: historyItems,
            seed: "\(baseSeed)|\(variant)",
            allowPetCopy: allowPetCopy
        )
    }

    static func tierIndex(for pack: ScenePackDefinition, amount: Double) -> Int {
        pack.tiers.firstIndex { amount <= $0.maxAmount } ?? max(0, pack.tiers.count - 1)
    }

    private static func contextualNotes(
        for pack: ScenePackDefinition,
        category: HomeItem.Category,
        date: Date,
        allowTravelSpecificCopy: Bool
    ) -> (key: String, notes: [String])? {
        let hour = Calendar.current.component(.hour, from: date)

        if pack.id == "travel",
           hour < 6,
           !allowTravelSpecificCopy,
           category != .lodging {
            return ("lateNightTravelNeutral", ["深夜这笔先记下", "夜里的一点小花费", "凌晨补上一笔", "晚归路上的小记录", "深夜日常一笔", "夜里这点花费记一下", "凌晨的小开销留个底", "夜深了也把账记稳"])
        }

        if pack.id == "food" || category == .dining {
            switch hour {
            case 5..<10:
                return ("breakfast", ["早餐简单吃一口", "晨间咖啡和小食", "上班前补点能量", "早饭热乎一下", "清晨的一份轻食", "早餐路上买一点", "豆浆包子早餐", "早间小食"])
            case 11..<14:
                return ("lunch", ["工作日午餐简餐", "中午一顿饭", "外卖点到工位", "食堂一份热乎饭", "午间补充能量", "忙里抽空吃顿饭", "约同事一起简吃", "饱腹又不折腾的一顿"])
            case 14..<17:
                return ("tea", ["下午茶小点心", "午后一杯饮品", "忙里偷闲喝点什么", "咖啡时间缓一缓", "给下午添点甜", "便利店轻食补给", "下午补一点能量", "茶歇时刻记一下"])
            case 17..<21:
                return ("dinner", ["晚餐一顿热饭", "下班后的一顿热饭", "晚餐小聚一份主菜", "做了一顿家常饭", "热腾腾的面或饭", "今晚吃得挺满足", "给一天收个尾", "晚饭时间坐一会儿"])
            default:
                return ("nightSnack", ["夜里补了一点夜宵", "加班后吃点热乎的", "深夜小食", "晚归路上的一口热食", "夜宵时间记下", "给夜晚补点能量", "夜里饿了吃一口", "深夜一顿热食"])
            }
        }

        if pack.id == "commute" || category == .transport {
            switch hour {
            case 7..<10:
                return ("morningCommute", ["早班通勤稳稳出发", "上班路上的一段车程", "早高峰顺利到达", "清晨出门的一笔路费", "赶早路上的交通记录", "地铁公交把我送到岗", "早间路线走完了", "今天也准时出发"])
            case 17..<21:
                return ("eveningCommute", ["下班路上的一段车程", "晚高峰回家", "结束一天后的返程", "回家路费记一下", "下班后的城市穿梭", "晚间通勤完成", "从工作切回生活", "回程路上松一口气"])
            default:
                return nil
            }
        }

        return nil
    }

    static func renderPetName(_ text: String, petName: String) -> String {
        text.replacingOccurrences(of: "{petName}", with: normalizedPetName(petName))
    }

    static func normalizedPetName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "小窝" : trimmed
    }

    private static func enrichNoteWithHistory(
        _ note: String,
        category: HomeItem.Category,
        date: Date,
        items: [HomeItem],
        seed: String,
        allowPetCopy: Bool
    ) -> String {
        note
    }

    private static func historyKeyword(category: HomeItem.Category, date: Date, items: [HomeItem]) -> String? {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -90, to: date) ?? .distantPast
        let counts = items
            .filter { $0.category == category && $0.createdAt >= start }
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.hasSuffix("消费") && $0.count >= 2 && $0.count <= 8 }
            .reduce(into: [String: Int]()) { result, title in
                result[title, default: 0] += 1
            }
        return counts.sorted {
            if $0.value == $1.value { return $0.key < $1.key }
            return $0.value > $1.value
        }
        .first?
        .key
    }

    private static func containsPetKeyword(_ text: String) -> Bool {
        ["猫", "狗", "宠物", "猫砂", "尿垫", "罐头", "冻干", "驱虫", "毛孩", "小窝"].contains {
            text.localizedCaseInsensitiveContains($0)
        }
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
