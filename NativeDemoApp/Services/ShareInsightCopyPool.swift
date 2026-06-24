import Foundation

enum ShareInsightCopyPool {
    static func insight(for signal: ShareInsightSignal, seed: String) -> ShareInsight {
        switch signal.kind {
        case let .sceneTop(lifeSignal, count):
            return sceneInsight(signal: lifeSignal, count: count, shareSignal: signal, seed: seed)
        case let .brandTop(name, count, brandId):
            return brandInsight(name: name, count: count, brandId: brandId, signal: signal, seed: seed)
        case let .categoryTop(category, count, context):
            return categoryInsight(category: category, count: count, context: context, signal: signal, seed: seed)
        case let .busiestDay(label, count):
            return ShareInsight(
                fact: "\(label)最忙，记了 \(count) 笔",
                care: pick(["那天事情多，回头也能看出来", "忙过的那天，先这样记着"], seed: seed + "|day"),
                footnote: footnote(for: signal),
                tags: ["#\(shortDayLabel(label))\(count)笔", "#\(signal.activeDays)天有记录", "#节奏更密", "#有记录的日子"]
            )
        case let .lifeMark(kind, title, line, label, count):
            let markName = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? title : label
            let markTag = kind == .milestone ? "#里程碑" : "#生活印记"
            return ShareInsight(
                fact: "这周留下「\(title)」",
                care: compactLifeMarkLine(line),
                footnote: footnote(for: signal),
                tags: [markTag, "#\(sanitizedTag(markName))", "#\(count)次", "#\(signal.activeDays)天有记录"]
            )
        case let .lifeTitle(text):
            return ShareInsight(
                fact: text,
                care: pick(["这句比分类更像这一周", "这句先放进这周的回看里"], seed: seed + "|life"),
                footnote: footnote(for: signal),
                tags: ["#\(signal.recordCount)笔记录", "#\(signal.activeDays)天有记录", "#手写备注", "#这一周有句子"]
            )
        case let .weakData(recordCount):
            return ShareInsight(
                fact: "这周记了 \(recordCount) 笔，先有个开头",
                care: pick(["再多几笔，回看会更完整", "先这样留着，下次会更清楚"], seed: seed + "|weak"),
                footnote: footnote(for: signal),
                tags: ["#\(recordCount)笔记录", "#\(signal.activeDays)天有记录", "#刚开头", "#多记几笔会更清楚"]
            )
        }
    }

    private static func brandInsight(
        name: String,
        count: Int,
        brandId: String?,
        signal: ShareInsightSignal,
        seed: String
    ) -> ShareInsight {
        let kind = brandKind(name: name, brandId: brandId)
        let fact: String
        let cares: [String]
        let semanticTag: String
        let leadingTag: String
        let rhythmTag: String
        switch kind {
        case .coffee:
            fact = "\(name)记了 \(count) 次"
            cares = ["这周靠咖啡提了几次神", "喝完这一杯，也早点睡"]
            semanticTag = "#咖啡"
            leadingTag = "#咖啡\(count)次"
            rhythmTag = "#忙里清醒"
        case .delivery:
            fact = "外卖记了 \(count) 次"
            cares = ["忙的时候先吃上就好", "有空再吃顿热乎的"]
            semanticTag = "#吃饭"
            leadingTag = "#外卖\(count)次"
            rhythmTag = "#先吃上"
        case .medical:
            fact = "\(name)记了 \(count) 次"
            cares = ["检查和问诊跑起来也费时间，今天先缓一缓", "身体的事先处理好，别拖着"]
            semanticTag = "#就医"
            leadingTag = "#就医\(count)次"
            rhythmTag = "#身体这边"
        case .medicine:
            fact = "\(name)记了 \(count) 次"
            cares = ["药和护理记清楚，后面少一点乱", "小不舒服先处理掉，别拖着"]
            semanticTag = "#用药护理"
            leadingTag = "#护理\(count)次"
            rhythmTag = "#身体事项"
        case .commute:
            fact = "\(name)记了 \(count) 次，这周通勤不少"
            cares = ["通勤路上的时间，也算这一周的一部分", "来回跑了不少，到家先缓一缓"]
            semanticTag = "#通勤"
            leadingTag = "#通勤\(count)次"
            rhythmTag = "#早晚路上"
        case .ride:
            fact = "\(name)用了 \(count) 次"
            cares = ["这周出门移动不少，到了就先歇口气", "能省点路上的力气，也挺好"]
            semanticTag = "#出行"
            leadingTag = "#出行\(count)次"
            rhythmTag = "#路上"
        case .convenience:
            fact = "\(name)记了 \(count) 次"
            cares = ["便利店这几次，像是在补忙碌里的小缺口", "路过买点需要的，也很真实"]
            semanticTag = "#便利店"
            leadingTag = "#补给\(count)次"
            rhythmTag = "#路过带上"
        case .food:
            fact = "\(name)记了 \(count) 次"
            cares = ["忙的时候先吃上，也很要紧", "这几顿先记清楚"]
            semanticTag = "#吃饭"
            leadingTag = "#吃饭\(count)次"
            rhythmTag = "#饭点在忙"
        case .general:
            fact = "\(name)出现了 \(count) 次"
            cares = ["反复出现的事，先当作这周的一个标记", "这个名字出现了好几次，先记下来"]
            semanticTag = "#反复出现"
            leadingTag = "#\(count)次\(sanitizedTag(name))"
            rhythmTag = "#这一周的标记"
        }
        return ShareInsight(
            fact: fact,
            care: pick(cares, seed: seed + "|brand|\(name)"),
            footnote: footnote(for: signal),
            tags: [leadingTag, "#\(signal.activeDays)天有记录", semanticTag, rhythmTag]
        )
    }

    private static func sceneInsight(
        signal: LifeSceneSignal,
        count: Int,
        shareSignal: ShareInsightSignal,
        seed: String
    ) -> ShareInsight {
        let copy = LifeSceneSemanticService.weeklyCopy(for: signal, count: count)
        let tags = [
            copy.leadingTag,
            "#\(shareSignal.activeDays)天有记录",
            copy.semanticTag,
            copy.supportTag
        ].compactMap { $0 }
        return ShareInsight(
            fact: copy.fact,
            care: pick(copy.cares, seed: seed + "|scene|\(signal.kind.rawValue)"),
            footnote: footnote(for: shareSignal),
            tags: tags
        )
    }

    private static func categoryInsight(
        category: HomeItem.Category,
        count: Int,
        context: ShareInsightSignal.CategoryContext,
        signal: ShareInsightSignal,
        seed: String
    ) -> ShareInsight {
        let fact: String
        let cares: [String]
        let tag: String
        let rhythmTag: String
        switch context {
        case .breakfast:
            fact = "早餐记了 \(count) 次"
            cares = ["赶早也吃上一口，就很好", "早上先垫一垫，别空着出门"]
            tag = "#早餐"
            rhythmTag = "#工作日前奏"
        case .coffee:
            fact = "咖啡饮品记了 \(count) 次"
            cares = ["这周靠它提了几次神", "喝完这一杯，也早点睡"]
            tag = "#提神"
            rhythmTag = "#忙里清醒"
        case .dining:
            fact = "吃饭记了 \(count) 次"
            cares = ["忙归忙，先吃上", "这几顿先记清楚"]
            tag = "#吃饭"
            rhythmTag = "#饭点在忙"
        case .commute:
            fact = "通勤路上记了 \(count) 笔"
            cares = ["通勤路上的时间，也算这一周的一部分", "来回跑了不少，到家先缓一缓"]
            tag = "#通勤"
            rhythmTag = "#早晚路上"
        case .travel:
            fact = "出行路上记了 \(count) 笔"
            cares = ["这周跑动不少，到了就先歇口气", "每一段路记下来，回头也清楚"]
            tag = "#出行"
            rhythmTag = "#城市里移动"
        case .medical:
            fact = "就医检查记了 \(count) 笔"
            cares = ["检查和问诊跑起来也费时间，今天先缓一缓", "身体的事先处理好，别拖着"]
            tag = "#就医"
            rhythmTag = "#身体这边"
        case .medicine:
            fact = "用药护理记了 \(count) 笔"
            cares = ["药和护理记清楚，后面少一点乱", "小不舒服先处理掉，别拖着"]
            tag = "#用药护理"
            rhythmTag = "#身体事项"
        case .fitness:
            fact = "锻炼记了 \(count) 次"
            cares = ["能动起来已经很好，别忘了休息", "保持住就好，不用每次都拉满"]
            tag = "#锻炼"
            rhythmTag = "#记得休息"
        case .care:
            fact = "身体护理记了 \(count) 笔"
            cares = ["小问题先处理掉，日子会轻一点", "把护理安排好，后面少一点乱"]
            tag = "#身体护理"
            rhythmTag = "#留点恢复时间"
        case .groceries:
            fact = "食材补给记了 \(count) 次"
            cares = ["把吃的备好，忙起来也少点乱", "厨房有东西，吃饭就不慌"]
            tag = "#食材"
            rhythmTag = "#家里烟火气"
        case .homeSupply:
            fact = "家用补给记了 \(count) 次"
            cares = ["缺的东西补上了，家里会顺一点", "这些小补给，确实会用得上"]
            tag = "#家用补给"
            rhythmTag = "#日常运转"
        case .shopping:
            fact = "网购添置记了 \(count) 笔"
            cares = ["买到需要的就好", "兴趣里的小投入，也会留下生活形状"]
            tag = "#快递到了"
            rhythmTag = "#兴趣装备"
        case .lodging:
            fact = "停留和住宿记了 \(count) 笔"
            cares = ["在外面也要睡踏实", "换个地方停下，也算这周的一段"]
            tag = "#停留"
            rhythmTag = "#在外面"
        case .social:
            fact = "人情往来记了 \(count) 笔"
            cares = ["见面和心意，都先记一笔", "这些来往，回头看会有用"]
            tag = "#人情"
            rhythmTag = "#有来有往"
        case .general:
            switch category {
            case .transport:
                fact = "路上记了 \(count) 笔，这周奔波不少"
                cares = ["移动也占精力，到家先缓一缓", "移动多的一周，留点空给自己"]
                tag = "#奔波"
                rhythmTag = "#城市里移动"
            case .health:
                fact = "健康相关记了 \(count) 笔"
                cares = ["身体的事，先处理好", "这些记录不是杂项，后面会用得上"]
                tag = "#健康"
                rhythmTag = "#身体这边"
            case .shopping:
                fact = "网购添置记了 \(count) 笔"
                cares = ["买到需要的就好", "兴趣里的小投入，也会留下生活形状"]
                tag = "#快递到了"
                rhythmTag = "#兴趣装备"
            case .dining:
                fact = "吃饭记了 \(count) 次"
                cares = ["忙归忙，先吃上", "这几顿先记清楚"]
                tag = "#吃饭"
                rhythmTag = "#饭点在忙"
            case .daily:
                fact = "日常补给记了 \(count) 次"
                cares = ["小东西补上了，后面少一点麻烦", "这些小补给，确实会用得上"]
                tag = "#日常"
                rhythmTag = "#日常运转"
            case .home:
                fact = "家里的事记了 \(count) 笔"
                cares = ["家里的事处理掉，会轻一点", "这些小事不显眼，但会影响每天"]
                tag = "#居家"
                rhythmTag = "#家里小事"
            case .entertainment:
                fact = "放松安排比较多，记了 \(count) 次"
                cares = ["该放松就放松", "这周也需要一点喘气的时间"]
                tag = "#放松"
                rhythmTag = "#留点余地"
            case .lodging:
                fact = "停留和住宿记了 \(count) 笔"
                cares = ["在外面也要睡踏实", "换个地方停下，也算这周的一段"]
                tag = "#停留"
                rhythmTag = "#在外面"
            case .social:
                fact = "人情往来记了 \(count) 笔"
                cares = ["见面和心意，都先记一笔", "这些来往，回头看会有用"]
                tag = "#人情"
                rhythmTag = "#有来有往"
            case .other:
                fact = "其他小事出现得最多，记了 \(count) 次"
                cares = ["说不清也没关系，先记下来", "先留着，之后再看也行"]
                tag = "#小事"
                rhythmTag = "#临时处理"
            }
        }
        return ShareInsight(
            fact: fact,
            care: pick(cares, seed: seed + "|category|\(category.rawValue)"),
            footnote: footnote(for: signal),
            tags: ["#\(category.label)\(count)次", "#\(signal.activeDays)天有记录", tag, rhythmTag]
        )
    }

    private enum BrandKind {
        case coffee
        case delivery
        case medical
        case medicine
        case commute
        case ride
        case convenience
        case food
        case general
    }

    private static func brandKind(name: String, brandId: String?) -> BrandKind {
        let id = brandId ?? ""
        if ["luckin", "starbucks", "manner"].contains(id) { return .coffee }
        if ["meituan", "eleme"].contains(id) { return .delivery }
        if ["metro_transit"].contains(id) { return .commute }
        if ["didi", "alipay_ride"].contains(id) { return .ride }
        if ["familymart", "lawson", "bianlifeng", "seveneleven", "meiyijia"].contains(id) { return .convenience }
        if ["mcdonalds", "kfc"].contains(id) { return .food }
        if name.contains("咖啡") { return .coffee }
        if name.contains("外卖") || name.contains("美团") || name.contains("饿了") { return .delivery }
        if containsAny(name, ["医院", "门诊", "诊所", "体检", "挂号", "口腔", "牙科"]) { return .medical }
        if containsAny(name, ["药店", "药房", "用药", "买药"]) { return .medicine }
        if name.contains("地铁") || name.contains("公交") || name.contains("轨道交通") { return .commute }
        if name.contains("滴滴") || name.contains("单车") || name.contains("打车") { return .ride }
        if name.contains("便利") || name.contains("全家") || name.contains("罗森") { return .convenience }
        return .general
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func footnote(for signal: ShareInsightSignal) -> String {
        let dayText = signal.activeDays > 0 ? " · \(signal.activeDays) 天有记录" : ""
        return "\(signal.recordCount) 笔 · 这一周\(dayText)"
    }

    private static func compactLifeMarkLine(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 34 else { return trimmed }
        return "\(trimmed.prefix(34))..."
    }

    private static func pick(_ options: [String], seed: String) -> String {
        guard !options.isEmpty else { return "" }
        return options[Int(stableHash(seed) % UInt64(options.count))]
    }

    private static func stableHash(_ text: String) -> UInt64 {
        text.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { partial, scalar in
            (partial ^ UInt64(scalar.value)) &* 1_099_511_628_211
        }
    }

    private static func sanitizedTag(_ text: String) -> String {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "／", with: "")
            .replacingOccurrences(of: "·", with: "")
        return String(cleaned.prefix(8))
    }

    private static func shortDayLabel(_ label: String) -> String {
        if label.contains("星期") {
            return label.replacingOccurrences(of: "星期", with: "周")
        }
        return label
    }
}
