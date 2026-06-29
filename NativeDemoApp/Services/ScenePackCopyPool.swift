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
            label: "地铁公交打车停车",
            desc: "通勤、短途办事、补能，出门这一趟都记这儿",
            category: .transport,
            tiers: [
                ScenePackTier(maxAmount: 5, notes: ["日常地铁通勤", "公交短途出行", "一段公共交通", "早间地铁到站", "公交地铁一段路", "今天的路费", "刷卡进站，到站", "短途公交到家"]),
                ScenePackTier(maxAmount: 15, notes: ["公交+地铁组合通勤", "下班高峰一段路", "打车到地铁站接驳", "通勤路上买瓶水", "今天出行少折腾", "固定路线，熟悉的路", "早晚通勤各记一笔", "公交地铁一段路"]),
                ScenePackTier(maxAmount: 30, notes: ["雨天打车通勤", "加班后打车回家", "共享单车月卡里的一天", "停车/补能小费用", "今天路程稍长一点", "路上多花了一点时间", "早晚两次出行", "这一程走完了"]),
                ScenePackTier(maxAmount: 9_999, notes: ["跨区通勤长途费", "出差市内交通", "高速/长途客车费", "一次较长的通勤路", "今天跑了不少路", "行程较满的一天路", "远距离往返", "为工作跑了不少路"]),
            ]
        ),
        ScenePackDefinition(
            id: "food",
            emoji: "🍵",
            label: "干饭点外卖和咖啡",
            desc: "早餐、午餐、夜宵、奶茶、便利店轻食",
            category: .dining,
            tiers: [
                ScenePackTier(maxAmount: 15, notes: ["晨间咖啡", "简单饮品", "早餐小食", "豆浆包子早餐组合", "午间一杯咖啡", "便利店轻食补给", "早茶点心小份", "早上快速吃一口"]),
                ScenePackTier(maxAmount: 25, notes: ["工作日午餐简餐", "外卖简单吃一顿", "食堂一份热乎饭", "下午茶小点心", "中午简单吃一顿", "饱腹又不折腾的一顿", "忙里喝点什么", "中午一顿饭"]),
                ScenePackTier(maxAmount: 40, notes: ["晚餐一份主菜", "周末早午餐", "尝试一家新店", "外卖送来一顿饭", "便当和轻食落下了", "一顿想吃的饭", "热腾腾的面或饭", "今天这顿记下"]),
                ScenePackTier(maxAmount: 9_999, notes: ["朋友小聚聚餐", "生日月吃一顿", "想吃了很久的一顿", "节日加菜", "家庭聚餐贡献一道", "认真吃一顿", "约会餐厅体验", "海鲜火锅这一顿"]),
            ]
        ),
        ScenePackDefinition(
            id: "supply",
            emoji: "🧻",
            label: "超市买菜和家用",
            desc: "清洁、纸巾、日用、即时零售、给家补货",
            category: .daily,
            tiers: [
                ScenePackTier(maxAmount: 20, notes: ["超市买点小东西", "纸巾清洁补一点", "便利店顺路补货", "今天给家补点", "买菜顺带一件日用", "小补给记下来", "缺的东西补上", "家用小补给"]),
                ScenePackTier(maxAmount: 80, notes: ["超市买菜和家用", "清洁纸巾一起补", "即时零售送到家", "给冰箱添点东西", "日用补货记一下", "便利店和超市这一单", "家里缺口补齐", "今天补货到位"]),
                ScenePackTier(maxAmount: 300, notes: ["家用集中补一轮", "买菜日用一起安排", "清洁和纸品补齐", "给家里添点底气", "这一单挺实用", "吃的用的都备上", "超市补货很具体", "把家里的日常补上"]),
                ScenePackTier(maxAmount: 9_999, notes: ["一轮家用大补货", "给家里集中备一批", "几天要用的都安排上", "超市这一单挺完整", "家里的日常更稳了", "把吃用都补齐", "长期会用的补上", "这次补货很踏实"]),
            ]
        ),
        ScenePackDefinition(
            id: "care",
            emoji: "🧘",
            label: "看病买药健身恢复",
            desc: "医院、药店、理疗、健身房、运动装备。撸铁重要，身体更重要",
            category: .health,
            tiers: [
                ScenePackTier(maxAmount: 20, notes: ["药店补一盒常备药", "运动后补点水和能量", "一支眼药水", "维生素或小药片", "创可贴和棉签备一点", "小不舒服先记下", "护具小物补上", "健康小物补齐"]),
                ScenePackTier(maxAmount: 60, notes: ["药店买药", "挂号问诊的一次记录", "换季护理用品补上", "牙膏牙线和口腔护理", "运动小物添置", "身体提醒先记下", "运动场地或课程一回", "小病小痛记下"]),
                ScenePackTier(maxAmount: 200, notes: ["一次检查", "牙科护理的一段记录", "理疗/康复一次", "体检项目先记下来", "训练装备升级一点", "恢复按摩安排一次", "问诊和用药都记清楚", "身体相关记录"]),
                ScenePackTier(maxAmount: 9_999, notes: ["体检套餐", "牙科治疗的一笔重要开销", "医院检查与治疗相关", "长期运动安排", "恢复相关安排", "运动大件添置", "身体相关大笔支出", "长期护理和训练安排"]),
            ]
        ),
        ScenePackDefinition(
            id: "home",
            emoji: "🏠",
            label: "每月房租水电物业",
            desc: "房租、水电燃气、物业、宽带、维修，住处每月要顾上的事",
            category: .home,
            tiers: [
                ScenePackTier(maxAmount: 20, notes: ["家里小维修", "住处小消耗", "临时家用一笔", "配件小修小补", "给住处添点方便", "住处这点花费", "家里缺的补一点", "家里的小消耗"]),
                ScenePackTier(maxAmount: 80, notes: ["住处日常开销一笔", "家里固定一笔日常", "家里实用小物", "住处运转的小日常", "家里的小维护", "住处相关记一下", "维修小费用", "居家小安排"]),
                ScenePackTier(maxAmount: 300, notes: ["家电小维修记一笔", "住处相关一笔日常", "给房间添一件东西", "床品收纳换新一点", "家里需要的东西补齐", "居住相关安排", "家里收拾一处", "这笔留给住处"]),
                ScenePackTier(maxAmount: 9_999, notes: ["家里重要一笔安排", "大件家电或家具添置", "搬家相关安排", "家里维修的一笔大项", "长期居住安排", "家的基础支出", "住处安稳下来", "为家安排的一笔"]),
            ]
        ),
        ScenePackDefinition(
            id: "social",
            emoji: "🎁",
            label: "请客吃饭人情局",
            desc: "聚餐、送礼、探望、红包、节日相聚",
            category: .social,
            tiers: [
                ScenePackTier(maxAmount: 30, notes: ["顺路带了点心意", "咖啡时间叙旧", "给这次见面留一句", "带了点心意记下", "路过时想起了对方", "一起坐坐这一回", "带点东西去见面", "日常往来一笔"]),
                ScenePackTier(maxAmount: 100, notes: ["聚会里的一段热闹", "请一顿饭叙旧", "节日里带份小礼", "同事小聚记一笔", "和朋友见面一回", "这次相聚记下来", "一顿饭里的熟悉感", "关系里的一点往来"]),
                ScenePackTier(maxAmount: 300, notes: ["探望时带了份心意", "家庭聚餐的一点贡献", "一次相聚记下", "重要日子里见一面", "给记挂的人添点东西", "团圆时刻的一笔记录", "赴约的一段记录", "这次见面记下"]),
                ScenePackTier(maxAmount: 9_999, notes: ["为一次相聚安排", "长途探望的一段记录", "仪式里的陪伴", "把这份记挂郑重记下", "为团圆多安排一点", "这一程是为了见面", "这次见面记清楚", "给牵挂的人留一笔"]),
            ]
        ),
        ScenePackDefinition(
            id: "shopping",
            emoji: "🛍️",
            label: "快递到了网购这件",
            desc: "淘宝京东拼多多、数码、服饰、兴趣装备和小众爱好",
            category: .shopping,
            tiers: [
                ScenePackTier(maxAmount: 30, notes: ["买个小物件", "给日常添一点方便", "看到合适的小东西", "小补给记一下", "刚好需要，就带回来了", "一点新鲜感", "给自己添个小物", "今天的小添置"]),
                ScenePackTier(maxAmount: 100, notes: ["补一件常用小物", "买到一件刚好需要的东西", "日常用品补齐", "兴趣装备添一件", "这件小东西挺实用", "逛到合适的就带回家", "爱好里的小投入", "把需要的东西安排上"]),
                ScenePackTier(maxAmount: 300, notes: ["挑了一件喜欢的", "给自己添一件好用的东西", "换新一件常用物", "这件会陪一阵子", "计划里的小升级", "把想买的那件拿下", "给喜欢的事添点装备", "买到一件合适的"]),
                ScenePackTier(maxAmount: 9_999, notes: ["入手一件大件", "长期使用的一次升级", "选过的一笔添置", "这件会用一阵子", "把心里惦记的东西带回来", "一次比较正式的换新", "给喜欢的事添点装备", "一个重要物件"]),
            ]
        ),
        ScenePackDefinition(
            id: "travel",
            emoji: "✈️",
            label: "出去玩订酒店买票",
            desc: "周末出走、高铁机票、门票、异地吃喝",
            category: .transport,
            tiers: [
                ScenePackTier(maxAmount: 20, notes: ["短途出行小消费", "沿途小吃记一笔", "出行便携物资采购", "景点门口一瓶水", "小城漫步小花费", "街边明信片或小挂件", "公交日票/景区摆渡", "旅途中的轻量补给"]),
                ScenePackTier(maxAmount: 80, notes: ["展馆/景点门票", "民宿小用品补买", "旅途一顿特色简餐", "城市漫步咖啡歇脚", "伴手礼试吃装", "租车/骑行小时费", "行程里的一笔小开销", "路边摊吃了一口"]),
                ScenePackTier(maxAmount: 200, notes: ["经济型住宿这一晚", "城际大巴/高铁一段", "特色餐厅体验", "博物馆联票", "旅行装备小升级", "行程中较充实的一天", "小镇住宿加早午餐", "为风景多走一段路"]),
                ScenePackTier(maxAmount: 9_999, notes: ["机票/高铁主段", "途中连住两晚", "行程里的重头戏", "目的地一日游团", "行李箱/装备购置", "长假出行大项", "带家人出门的一程", "这次行程记下"]),
            ]
        ),
        ScenePackDefinition(
            id: "family",
            emoji: "🍼",
            label: "娃和毛孩的补给站",
            desc: "奶粉尿不湿、宠物粮猫砂、洗护就医，家里小成员的日常照护",
            category: .daily,
            tiers: [
                ScenePackTier(maxAmount: 30, notes: ["家里小成员补点日常", "奶粉尿不湿或小零食先补上", "猫砂尿垫和湿巾这类小消耗", "照护路上的一笔", "今天给家里小成员添一点", "小衣物小点心补上", "日常消耗记下", "小补给先到位"]),
                ScenePackTier(maxAmount: 100, notes: ["娃和毛孩的日用品补货", "奶粉辅食和宠物口粮都算这里", "尿不湿湿巾或猫砂罐头补齐", "洗护用品安排上", "家里小成员需要的先补上", "照护用品到位", "口粮和日用品补一轮", "这笔留给家里小成员"]),
                ScenePackTier(maxAmount: 300, notes: ["照护用品集中补货", "奶粉尿不湿囤一点", "宠物粮猫砂补一轮", "童装推车或宠物用品添置", "洗护就医相关一笔记清楚", "家里小成员的长期用品安排好", "成长和照护一起记下", "这次补给挺完整"]),
                ScenePackTier(maxAmount: 9_999, notes: ["家里小成员的大件安排", "母婴或宠物大项认真记下", "儿童座椅、推车或宠物就医相关", "照护计划里重要的一笔", "给家里小成员准备长期会用的", "家里照护配置升级", "成长阶段的大笔开销", "这笔留给家里小成员成长"]),
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
            allowTravelSpecificCopy: allowTravelSpecificCopy,
            historyItems: historyItems
        )
        let notes = context?.notes ?? tier.notes
        let baseSeed = "\(dayKey(for: date))|\(pack.id)|\(tierIndex)|\(categoryContext.rawValue)|\(context?.key ?? "tier")"
        let baseIndex = stableIndex(seed: baseSeed, count: notes.count)
        let index = (baseIndex + max(0, variant)) % max(1, notes.count)
        let rendered = sanitizeLifeNote(renderPetName(notes[index], petName: petName))
        let contextualized = contextualizeNote(
            rendered,
            pack: pack,
            category: categoryContext,
            date: date,
            historyItems: historyItems
        )
        return enrichNoteWithHistory(
            contextualized,
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
        allowTravelSpecificCopy: Bool,
        historyItems: [HomeItem]
    ) -> (key: String, notes: [String])? {
        let hour = Calendar.current.component(.hour, from: date)

        if pack.id == "travel",
           (hour >= 22 || hour < 6),
           !allowTravelSpecificCopy,
           category != .lodging {
            return ("lateNightTravelNeutral", ["深夜这笔先记下", "夜里的一点小花费", "凌晨补上一笔", "晚归路上的小开销", "深夜日常一笔", "夜里这点花费记一下", "凌晨的小开销留个底", "夜深了也把账记稳"])
        }

        if pack.id == "food" || category == .dining {
            switch hour {
            case 5..<10:
                if shouldUseWorkdayCopy(date: date, historyItems: historyItems) {
                    return ("breakfast", ["早餐简单吃一口", "晨间咖啡和小食", "上班前补点能量", "早饭热乎一下", "清晨的一份轻食", "早餐路上买一点", "豆浆包子早餐", "早间小食"])
                }
                return ("weekendBreakfast", ["早餐简单吃一口", "晨间咖啡和小食", "早饭热乎一下", "清晨的一份轻食", "早餐路上买一点", "豆浆包子早餐", "早间小食", "周末早餐有着落"])
            case 11..<14:
                if shouldUseWorkdayMealCopy(date: date, historyItems: historyItems) {
                    return ("lunch", ["工作日午餐简餐", "中午一顿饭", "外卖点到工位", "食堂一份热乎饭", "中午吃一顿", "忙里抽空吃顿饭", "中午简单吃一顿", "饱腹又不折腾的一顿"])
                }
                return ("weekendLunch", ["周末午餐简单吃一顿", "午间吃点热乎的", "周末中午补点能量", "今天午饭先记下", "中午吃得简单一点", "午间一顿饭", "周末饭点留一笔", "这顿午饭记下"])
            case 14..<17:
                if shouldUseWorkdayCopy(date: date, historyItems: historyItems) {
                    return ("tea", ["下午茶小点心", "午后一杯饮品", "忙里喝点什么", "咖啡时间记一下", "给下午添点甜", "便利店轻食补给", "下午补一点能量", "茶歇时刻记一下"])
                }
                return ("weekendTea", ["下午茶小点心", "午后一杯饮品", "咖啡时间记一下", "给下午添点甜", "便利店轻食补给", "下午补一点能量", "茶歇时刻记一下", "周末下午吃点小的"])
            case 17..<21:
                if shouldUseWorkdayCopy(date: date, historyItems: historyItems) {
                    return ("dinner", ["晚餐一顿热饭", "下班后的一顿热饭", "晚餐小聚一份主菜", "做了一顿家常饭", "热腾腾的面或饭", "今晚吃得挺实在", "给一天收个尾", "晚饭时间坐一会儿"])
                }
                return ("weekendDinner", ["晚餐一顿热饭", "晚餐小聚一份主菜", "做了一顿家常饭", "热腾腾的面或饭", "今晚吃得挺实在", "给一天收个尾", "晚饭时间坐一会儿", "周末晚饭记下"])
            default:
                if shouldUseWorkdayCopy(date: date, historyItems: historyItems) {
                    return ("nightSnack", ["夜里补了一点夜宵", "加班后吃点热乎的", "深夜小食", "晚归路上的一口热食", "夜宵时间记下", "夜里补点吃的", "夜里饿了吃一口", "深夜一顿热食"])
                }
                return ("nightSnackNeutral", ["夜里补了一点夜宵", "深夜小食", "晚归路上的一口热食", "夜宵时间记下", "夜里补点吃的", "夜里饿了吃一口", "深夜一顿热食", "夜里这口先垫一下"])
            }
        }

        if pack.id == "commute" || category == .transport {
            switch hour {
            case 7..<10:
                if shouldUseWorkdayCopy(date: date, historyItems: historyItems) {
                    return ("morningCommute", ["早上路上这一程", "早间的一笔路费", "早高峰这一段", "清晨出门的一笔路费", "赶早路上的交通记录", "地铁公交到站", "早上这趟路走完了", "今天的出行记下"])
                }
                return ("weekendMorningRoute", ["早上出门的一段路", "清晨出门的一笔路费", "早上这趟路走完了", "今天的出行记下", "短途出行记一下", "公交地铁一段路", "这一程走完了", "早上的路费"])
            case 17..<21:
                if shouldUseWorkdayCopy(date: date, historyItems: historyItems) {
                    return ("eveningCommute", ["下班路上这一程", "晚高峰回家", "结束一天后的返程", "回家路费记一下", "下班后的回家路", "下班这趟路到家了", "下班回到家这边", "回程路上少赶一点"])
                }
                return ("weekendEveningRoute", ["傍晚的一段路", "回家路费记一下", "晚间出行完成", "回到家这边", "回程路上少赶一点", "这一程走完了", "晚上路费记一下", "短途回程"])
            default:
                return nil
            }
        }

        return nil
    }

    private static func shouldUseWorkdayMealCopy(date: Date, historyItems: [HomeItem]) -> Bool {
        guard isWeekend(date) else { return true }
        guard shouldUseWorkdayCopy(date: date, historyItems: historyItems) else { return false }
        return historyItems.contains { item in
            guard item.source == .manual,
                  item.category == .dining,
                  isWeekend(item.createdAt) else { return false }
            return containsWeekendWorkMealCue("\(item.title) \(item.emotionTag)")
        }
    }

    private static func shouldUseWorkdayCopy(date: Date, historyItems: [HomeItem]) -> Bool {
        guard isWeekend(date) else { return true }
        return historyItems.contains { item in
            guard item.source == .manual, isWeekend(item.createdAt) else { return false }
            return containsWeekendWorkCue("\(item.title) \(item.emotionTag)")
        }
    }

    private static func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private static func containsWeekendWorkMealCue(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("周末食堂") { return true }
        let mealCue = ["食堂", "午餐", "饭", "餐", "外卖", "热饭"].contains { lower.contains($0) }
        let workCue = ["加班", "公司", "单位", "工位", "工作餐"].contains { lower.contains($0) }
        return mealCue && workCue
    }

    private static func containsWeekendWorkCue(_ text: String) -> Bool {
        let lower = text.lowercased()
        return ["加班", "公司", "单位", "工位", "工作餐", "到岗", "下班", "上班", "通勤"].contains {
            lower.contains($0)
        }
    }

    private static func contextualizeNote(
        _ note: String,
        pack: ScenePackDefinition,
        category: HomeItem.Category,
        date: Date,
        historyItems: [HomeItem]
    ) -> String {
        var text = note
        if !shouldUseWorkdayCopy(date: date, historyItems: historyItems) {
            text = neutralizeWorkdayCue(text, category: category, date: date)
        }
        if pack.id != "travel",
           category != .lodging,
           containsTravelKeyword(text),
           !containsTravelIntent(in: historyItems, near: date) {
            text = neutralizeTravelCue(text, category: category)
        }
        return sanitizeLifeNote(text)
    }

    private static func neutralizeWorkdayCue(_ note: String, category: HomeItem.Category, date: Date) -> String {
        var text = note
        let replacements: [(String, String)] = [
            ("工作日午餐简餐", "中午简单吃一顿"),
            ("外卖点到工位", "外卖简单吃一顿"),
            ("食堂一份热乎饭", "午间吃点热乎的"),
            ("上班前快速吃一口", "早上快速吃一口"),
            ("上班前补点能量", "早上补点能量"),
            ("下班后的一顿热饭", "晚餐一顿热饭"),
            ("加班后吃点热乎的", "夜里吃点热乎的"),
            ("加班后打车回家", "晚点打车回家"),
            ("为工作跑了不少路", "今天跑了不少路"),
            ("出差市内交通", "市内交通一段"),
            ("早班地铁到岗", "早间地铁到站"),
            ("地铁公交到岗", "地铁公交到站"),
            ("上班路上的一段车程", "早上路上这一程"),
            ("下班路上的一段车程", "下班路上这一程"),
            ("下班后的回家路", "晚间回家路"),
            ("下班回到家这边", "回到家这边"),
            ("晚间通勤完成", "下班这趟路到家了"),
            ("早晚通勤各记一笔", "今天出行记一笔"),
            ("通勤路上买瓶水", "路上买瓶水"),
            ("通勤多花了一点时间", "路上多花了一点时间"),
            ("一次较长的通勤路", "一次较长的出行"),
            ("跨区通勤长途费", "跨区出行长途费"),
        ]
        for replacement in replacements {
            text = text.replacingOccurrences(of: replacement.0, with: replacement.1)
        }
        if category == .transport, containsWorkdayRouteKeyword(text) {
            return routeFallback(for: date)
        }
        if category == .dining, containsWorkdayMealKeyword(text) {
            return diningFallback(for: date)
        }
        return text
    }

    private static func neutralizeTravelCue(_ note: String, category: HomeItem.Category) -> String {
        guard category != .lodging else { return note }
        var text = note
        let replacements: [(String, String)] = [
            ("旅途中的轻量补给", "路上的轻量补给"),
            ("旅途一顿特色简餐", "路上一顿简餐"),
            ("旅行装备小升级", "出行装备小升级"),
            ("这次行程记下", "这笔行程记下"),
            ("行程里的一笔小开销", "路上的一笔小开销"),
            ("行程中较充实的一天", "今天安排得比较满"),
            ("长假出行大项", "出行大项记下"),
        ]
        for replacement in replacements {
            text = text.replacingOccurrences(of: replacement.0, with: replacement.1)
        }
        return text
    }

    private static func containsWorkdayRouteKeyword(_ text: String) -> Bool {
        ["上班", "下班", "到岗", "通勤", "加班", "工作"].contains { text.contains($0) }
    }

    private static func containsWorkdayMealKeyword(_ text: String) -> Bool {
        ["食堂", "工位", "工作日", "工作餐", "加班", "忙里"].contains { text.contains($0) }
    }

    private static func containsTravelKeyword(_ text: String) -> Bool {
        ["旅行", "旅途", "景区", "景点", "行程", "酒店", "民宿", "住宿", "机票", "高铁", "机场", "返程", "摆渡"].contains {
            text.contains($0)
        }
    }

    private static func containsTravelIntent(in items: [HomeItem], near date: Date) -> Bool {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -3, to: date) ?? date
        let end = calendar.date(byAdding: .day, value: 3, to: date) ?? date
        return items.contains { item in
            item.createdAt >= start
                && item.createdAt <= end
                && containsTravelKeyword("\(item.title) \(item.emotionTag)")
        }
    }

    private static func routeFallback(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return "早上出门的一段路"
        case 17..<22: return "傍晚的一段路"
        default: return "今天的一段路"
        }
    }

    private static func diningFallback(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<10: return "早上简单吃点"
        case 11..<14: return "午间吃点热乎的"
        case 17..<21: return "晚餐一顿热饭"
        default: return "夜里吃点东西"
        }
    }

    static func renderPetName(_ text: String, petName: String) -> String {
        text.replacingOccurrences(of: "{petName}", with: normalizedPetName(petName))
    }

    static func normalizedPetName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "小窝" : trimmed
    }

    private static func sanitizeLifeNote(_ note: String) -> String {
        let replacements: [(String, String)] = [
            ("顺带记下", "记下"),
            ("小确幸", "小记录"),
            ("好好", ""),
            ("温柔", "轻一点"),
            ("被看见", "被记下"),
            ("被接住", "有了着落"),
            ("接住", "记下"),
            ("治愈", "缓一缓"),
            ("你值得", "今天可以"),
            ("生活角落", "日常角落"),
            ("小奖励", "想买的这一件"),
            ("给自己一点软软的好", "买了点面包甜品"),
            ("高光", "清楚的一笔"),
            ("打卡", "记下"),
            ("温度", "记录"),
        ]
        return replacements.reduce(note) { result, pair in
            result.replacingOccurrences(of: pair.0, with: pair.1)
        }
        .replacingOccurrences(of: "  ", with: " ")
        .replacingOccurrences(of: "茶香喝", with: "这杯茶慢点喝")
        .replacingOccurrences(of: "这一口喝完", with: "这一口喝完了")
        .replacingOccurrences(of: "把这一会儿下来", with: "这一会儿慢下来")
        .trimmingCharacters(in: .whitespacesAndNewlines)
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
