import Foundation

enum PetCompanionCopy {
    static let companion = [
        "我在这儿陪你，一起把钱花明白。",
        "每一笔记录，都是在帮未来的你减压，{petName}一直在。",
        "慢慢来，记账不是为了苛责自己，而是更了解自己。",
        "不想被打扰的话，长按我就能把我藏起来啦。",
    ]

    static let recordSaved = [
        "记下来的每一笔，都是你的掌控感呀！{petName}为你点赞～",
        "今天也按时记账啦，你超棒的！",
        "这笔记录得很好，继续保持这个节奏～",
        "今天的小快乐，也被好好记下来了。",
    ]

    static let lightScene = [
        "今天的奶茶 / 咖啡，也记得记录一下哦～",
        "偶尔的小快乐，也要好好记下来呀。",
    ]

    static let weatherHint = [
        "如果开启定位，我可以根据天气陪你说悄悄话，治愈感满满哦～",
        "允许获取天气后，我会更懂你的小日常。",
        "天冷、降温、下雨天，我都可以温柔提醒你，要不要浅浅授权一下？（前往设置开启）",
    ]

    static let weatherAiFallback = [
        "今天的天气和你的消费节奏都很温和，{petName}觉得你把日子安排得刚刚好。",
        "我看了看今天的花费和天气，整体都很稳，按这个节奏生活就很舒服。",
        "不管晴天还是阴天，你今天的每一笔都很踏实，慢慢记录就会更安心。",
        "今天的消费主要在日常刚需，天气也很配合，{petName}继续陪你轻松记账。",
    ]

    static let weatherContext: [String: [String]] = [
        "coldDrink": [
            "今天外面有点冷，你这杯热饮刚好暖到了自己。小小花费，是给自己的温柔，不用焦虑。",
        ],
        "weekendRelax": [
            "难得的周末放松一下，这笔快乐消费很值得，你值得好好奖励自己。",
        ],
        "lateNightSnack": [
            "忙了一天，深夜的小奖励很正常。偶尔的小放松，不需要苛责自己。",
        ],
        "hotNoCool": [
            "今天好热呀～要不要奖励自己一杯小饮料呢？",
            "外面热乎乎的，{petName}想提醒你：来点清凉小快乐也不错呀。",
            "天气这么热，给自己安排一份清爽小补给吧，我举爪支持你～",
        ],
        "rainyHome": [
            "外面在下雨，今天在家慢慢待着也很治愈，给自己一点松弛感吧。",
            "雨天最适合把节奏放慢，{petName}陪你把今天过得软乎乎的。",
            "下雨天就别赶路啦，窝在舒服的小角落里，也是一种温柔生活。",
        ],
        "monthEndSoft": [
            "快到月末啦，这个月你已经很认真记录了，接下来慢慢花、慢慢过就很好。",
            "月末节奏稍快也没关系，{petName}陪你把日子过稳稳的，不着急。",
            "这个月辛苦啦，月末给自己一点从容感，按你的节奏继续就很棒。",
        ],
        "weekendHealing": [
            "周末到啦，今天就轻松一点，去做一件让自己开心的小事吧。",
            "周末是补充能量的好时候，花点小钱换一点松弛感，也很值得。",
            "难得周末，记账继续，快乐也继续，{petName}陪你慢慢享受生活。",
        ],
        "noExpenseCalm": [
            "今天还没花钱也没关系，按自己的节奏生活就很好，{petName}在这儿陪你。",
            "今天像一口慢慢呼吸的空气，没消费也很正常，舒服就好。",
        ],
        "commuteSteady": [
            "今天通勤开销很稳定，你的生活节奏真的很有秩序感。",
            "这几笔出行花费都很日常，稳稳当当地过日子就很安心。",
        ],
        "groceryWarm": [
            "今天把生活小补给安排得很好，柴米油盐也是被认真照顾的温柔。",
            "这些日用和餐饮花费很踏实，日子被你收拾得暖暖的。",
        ],
        "highSpendComfort": [
            "今天花得稍微多一点也没关系，重要的是你有在认真记录和感受生活。",
            "偶尔高一点的开销很正常，{petName}陪你慢慢把节奏找回来就好。",
        ],
    ]

    static func personalized(_ text: String, settings: AppSettings) -> String {
        let name = settings.petNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.replacingOccurrences(of: "{petName}", with: name.isEmpty ? "小窝" : name)
    }

    static func random(_ list: [String], settings: AppSettings) -> String {
        personalized(list.randomElement() ?? "", settings: settings)
    }

    static func weatherContextMessage(_ key: String, settings: AppSettings) -> String? {
        guard let block = weatherContext[key] else { return nil }
        return random(block, settings: settings)
    }
}
