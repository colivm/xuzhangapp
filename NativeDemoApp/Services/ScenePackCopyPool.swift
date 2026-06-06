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
                ScenePackTier(maxAmount: 5, notes: ["日常地铁通勤出行", "公交短途出行打卡", "选择绿色出行，简单省心", "早班地铁，稳稳到岗", "换乘一小段，通勤完成", "今天的路费，很日常", "刷卡进站，出发啦", "短途公交，省心到家"]),
                ScenePackTier(maxAmount: 15, notes: ["公交+地铁组合通勤", "下班高峰一段路", "打车到地铁站接驳", "通勤路上买瓶水", "今日出行主打省心", "固定路线，熟悉的感觉", "早晚通勤各记一笔", "城市穿梭的小开销"]),
                ScenePackTier(maxAmount: 30, notes: ["雨天打车通勤", "加班后打车回家", "共享单车月卡里的一天", "停车/充电小费用", "今天路程稍长一点", "通勤多花了一点时间换舒适", "早晚两次出行", "为一程准时到达"]),
                ScenePackTier(maxAmount: 9_999, notes: ["跨区通勤长途费", "出差市内交通", "高速/长途客车费", "一次性通勤大额支出", "今天跑了不少路", "行程较满的交通开销", "远距离往返", "为工作奔波的一天"]),
            ]
        ),
        ScenePackDefinition(
            id: "food",
            emoji: "🍵",
            label: "吃货专属包",
            desc: "吃喝里的一小句生活",
            category: .dining,
            tiers: [
                ScenePackTier(maxAmount: 15, notes: ["晨间咖啡唤醒日常", "简单饮品放松心情", "随手添置早餐小食", "豆浆包子早餐组合", "午前一杯奶茶小确幸", "便利店轻食补给", "早茶点心小份", "上班前快速吃一口"]),
                ScenePackTier(maxAmount: 25, notes: ["工作日午餐简餐", "外卖点到工位", "食堂一份热乎饭", "下午茶小点心", "约同事一起简吃", "饱腹又不折腾的一顿", "忙里偷闲喝点什么", "中午好好吃一口"]),
                ScenePackTier(maxAmount: 40, notes: ["晚餐小聚一份主菜", "周末早午餐放松", "尝试一家新店", "买菜顺路带点卤味", "认真做了一顿家常饭", "犒劳自己的一顿好饭", "热腾腾的面或饭", "今天吃得挺满足"]),
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
                ScenePackTier(maxAmount: 20, notes: ["药店顺手补一盒常备药", "买了点日常护理小物", "一支眼药水的小照顾", "补充维生素或小药片", "创可贴和棉签备一点", "今天把小不舒服照看住", "给身体留一点安心", "健康小物补齐了"]),
                ScenePackTier(maxAmount: 60, notes: ["药店买药，先照顾好自己", "挂号问诊的一次记录", "换季护理用品补上", "牙膏牙线和口腔护理", "运动后买点恢复用品", "身体提醒我慢一点", "给自己安排基础护理", "小病小痛，认真记下"]),
                ScenePackTier(maxAmount: 200, notes: ["一次检查，把心放稳一点", "牙科护理的一段小支出", "理疗/康复的一次照顾", "体检项目先记下来", "给身体做一次认真回应", "把健康这件事放在心上", "问诊和用药都记清楚", "今天是在好好照顾自己"]),
                ScenePackTier(maxAmount: 9_999, notes: ["体检套餐，给自己一份安心", "牙科治疗的一笔重要开销", "医院检查与治疗相关", "长期护理用品一次补齐", "为身体恢复安排的一程", "健康这件大事，值得记下", "这笔是对自己的认真照看", "把身体放回生活的主位"]),
            ]
        ),
        ScenePackDefinition(
            id: "home",
            emoji: "🏠",
            label: "居家安顿包",
            desc: "家里的日常，也是一段生活",
            category: .home,
            tiers: [
                ScenePackTier(maxAmount: 20, notes: ["家里顺手补个小物件", "厨房小用品补上了", "一卷纸巾，一点安顿", "清洁小物让家更舒服", "今天给家添了一点方便", "小修小补也算照顾家", "生活角落被补齐一点", "家里的小消耗记一下"]),
                ScenePackTier(maxAmount: 80, notes: ["日化清洁用品补货", "水电燃气的一笔日常", "给家里添点实用小物", "宽带/话费这类固定支出", "厨房和卫生间补给", "家里运转的小开销", "把日子打理得顺一点", "居家小补给安排上"]),
                ScenePackTier(maxAmount: 300, notes: ["家电小维修记一笔", "物业/宽带相关支出", "给房间添一件舒服东西", "床品收纳换新一点", "家里需要的东西补齐", "为住得舒服多安排一点", "把家慢慢收拾好", "这笔让家更像家"]),
                ScenePackTier(maxAmount: 9_999, notes: ["房租/押金相关支出", "大件家电或家具添置", "搬家相关的一段开销", "家里维修的一笔大项", "给长期生活做一次安顿", "这笔是家的基础感", "把住处安稳下来", "为家认真安排的一笔"]),
            ]
        ),
        ScenePackDefinition(
            id: "travel",
            emoji: "✈️",
            label: "旅行出发包",
            desc: "路上的花费，也值得记下",
            category: .transport,
            tiers: [
                ScenePackTier(maxAmount: 20, notes: ["短途出行小消费", "沿途小吃简单打卡", "出行便携物资采购", "景点门口一瓶水", "小城漫步小花费", "街边明信片或小挂件", "公交日票/景区摆渡", "旅途中的轻量补给"]),
                ScenePackTier(maxAmount: 80, notes: ["展馆/景点门票", "民宿小用品补买", "旅途一顿特色简餐", "城市漫步咖啡歇脚", "伴手礼试吃装", "租车/骑行小时费", "行程里的一笔小惊喜", "路边摊体验打卡"]),
                ScenePackTier(maxAmount: 200, notes: ["经济型住宿这一晚", "城际大巴/高铁一段", "特色餐厅体验", "博物馆联票", "旅行装备小升级", "行程中较充实的一天", "小镇住宿加早午餐", "为风景多走一段路"]),
                ScenePackTier(maxAmount: 9_999, notes: ["机票/高铁主段", "途中连住两晚", "行程里的重头戏", "目的地一日游团", "行李箱/装备购置", "长假出行大项", "带家人出门的一程", "值得记住的一次出发"]),
            ]
        ),
        ScenePackDefinition(
            id: "pet",
            emoji: "🐱",
            label: "铲屎官宠物包",
            desc: "{petName} 相关的小开销",
            category: .daily,
            tiers: [
                ScenePackTier(maxAmount: 20, notes: ["给{petName}买了小零食", "给{petName}安排美味小点心", "补货宠物消耗小用品", "顺手囤一包冻干", "给{petName}挑个小玩具", "猫砂/尿垫补货", "给{petName}加一罐罐头", "毛孩的小零食时间"]),
                ScenePackTier(maxAmount: 60, notes: ["为{petName}购置口粮用品", "给{petName}囤上爱吃的罐头", "入手小玩具，陪伴{petName}玩耍", "宠物洗护用品补货", "给{petName}买新碗新窝配件", "驱虫药常备补货", "毛孩营养膏一支", "给{petName}添件舒适用品"]),
                ScenePackTier(maxAmount: 150, notes: ["购入{petName}专用主食与冻干", "安排{petName}日常驱虫护理", "带{petName}洗护美容，清爽干净", "宠物医院常规检查", "换季毛发护理开销", "给{petName}升级主食粮", "宠物保险/会员续费", "大件猫爬架小分期"]),
                ScenePackTier(maxAmount: 9_999, notes: ["带{petName}体检接种疫苗", "添置居家小窝与攀爬家具", "{petName}就医护理相关开销", "为{petName}选购高端营养口粮", "宠物手术/治疗相关", "长途托运或寄养费用", "给{petName}安排年度体检套餐", "毛孩的大件生活升级"]),
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
        allowPetCopy: Bool = true
    ) -> String {
        let tierIndex = tierIndex(for: pack, amount: amount)
        let tier = pack.tiers[tierIndex]
        let seed = "\(dayKey(for: date))|\(pack.id)|\(tierIndex)|\(categoryContext.rawValue)"
        let index = stableIndex(seed: seed, count: tier.notes.count)
        let rendered = renderPetName(tier.notes[index], petName: petName)
        return enrichNoteWithHistory(
            rendered,
            category: categoryContext,
            date: date,
            items: historyItems,
            seed: seed,
            allowPetCopy: allowPetCopy
        )
    }

    static func tierIndex(for pack: ScenePackDefinition, amount: Double) -> Int {
        pack.tiers.firstIndex { amount <= $0.maxAmount } ?? max(0, pack.tiers.count - 1)
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
        guard stableIndex(seed: seed + "|historyChance", count: 100) < 45,
              let keyword = historyKeyword(category: category, date: date, items: items),
              allowPetCopy || !containsPetKeyword(keyword),
              !note.contains(keyword) else {
            return note
        }
        return "\(note)，顺带记下「\(keyword)」"
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
