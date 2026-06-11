import Foundation

enum PetCompanionCopy {
    static let companion = [
        "我在这儿，陪你把今天记清楚。",
        "有一笔就记一笔，{petName}在旁边看着。",
        "不急，先留下这一笔。",
        "不想被打扰的话，长按我就能把我藏起来啦。",
    ]

    static let recordSaved = [
        "已记下，回头能在账本里找到。",
        "这一笔已经留在今天。",
        "记录好了，可以继续下一件事。",
        "这笔先收进账本。",
    ]

    static let lightScene = [
        "奶茶 / 咖啡也可以留一句。",
        "小花费也能先记下。",
    ]

    static let weatherHint = [
        "开启天气后，雨天、降温这些情况会多一句提示。",
        "允许获取天气后，提示会更贴近当天。",
        "天冷、降温、下雨天，可以顺手补一句记录。（前往设置开启）",
    ]

    static let weatherAiFallback = [
        "今天的天气和花费先记到这里。",
        "今天的记录不多，先按现有几笔看。",
        "晴天或阴天，都先把账本留清楚。",
        "今天主要是日常花费，{petName}陪你记着。",
    ]

    static let weatherContext: [String: [String]] = [
        "coldDrink": [
            "今天外面有点冷，这杯热饮可以留一句。",
        ],
        "weekendRelax": [
            "周末这笔休闲花费，先记下来。",
        ],
        "lateNightSnack": [
            "深夜这笔小食，记清时间就好。",
        ],
        "hotNoCool": [
            "今天很热，饮料这类小花费也可以记下。",
            "外面热，清凉饮品也可以留一句。",
            "热天的小补给，记一笔就行。",
        ],
        "rainyHome": [
            "外面在下雨，家里的花费可以按日常记。",
            "雨天记录先放轻，记清这一笔就好。",
            "下雨天的居家小开销，留在今天。",
        ],
        "monthEndSoft": [
            "快到月末了，这几笔会进入月记。",
            "月末记录先保持清楚，之后再回看。",
            "这个月快收尾了，今天这笔也留上。",
        ],
        "weekendHealing": [
            "周末这笔，留个简单备注也可以。",
            "周末小花费，记下场景就够。",
            "周末这笔先放进账本。",
        ],
        "noExpenseCalm": [
            "今天还没花钱，账本先空着也可以。",
            "今天还没有记录，等有一笔再写。",
        ],
        "commuteSteady": [
            "今天通勤开销比较稳定。",
            "这几笔出行花费都很日常。",
        ],
        "groceryWarm": [
            "今天有一些日常补给。",
            "这些日用和餐饮花费都先记清楚。",
        ],
        "highSpendComfort": [
            "今天金额高一点，先把明细留清楚。",
            "这笔金额比较高，备注可以写具体一点。",
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
