import Foundation

enum PetCompanionCopy {
    struct Message: Equatable {
        let id: String
        let text: String
    }

    static let recordSaved = [
        Message(id: "saved.neutral.1", text: "这笔已经记下了。"),
        Message(id: "saved.neutral.2", text: "记录好了，想起别的再补。"),
        Message(id: "saved.neutral.3", text: "这一笔已经留在账本里。"),
    ]

    static let noRecords = [
        Message(id: "day.empty.1", text: "今天还没有记录，我在这儿陪你。"),
        Message(id: "day.empty.2", text: "今天这一页还空着，我就在旁边。"),
    ]

    static let oneRecord = [
        Message(id: "day.one.1", text: "今天已经留下一笔了，想起别的再补。"),
        Message(id: "day.one.2", text: "今天的一笔已经在账本里。"),
    ]

    static let severalRecords = [
        Message(id: "day.several.1", text: "今天的几笔都在，晚点回看也来得及。"),
        Message(id: "day.several.2", text: "今天已经记下几笔了，先按自己的节奏来。"),
    ]

    static let evening = [
        Message(id: "day.evening.1", text: "今天先记到这里也可以。"),
        Message(id: "day.evening.2", text: "晚一点了，今天记到这里也行。"),
    ]

    static let companion = [
        Message(id: "companion.1", text: "我在这儿，想起一笔就记一笔。"),
        Message(id: "companion.2", text: "不急，按自己的节奏记。"),
        Message(id: "companion.3", text: "{petName}在这儿，想起什么再补。"),
    ]

    static let interactionHints = [
        Message(id: "interaction.move_hide.1", text: "如果我挡住了，拖一拖就能换个位置；长按我，我就先去休息。"),
        Message(id: "interaction.move_hide.2", text: "想换个位置就拖动我，想让我休息一会儿就长按我。"),
    ]

    static let hotWeatherCare = [
        Message(id: "weather.hot.care.1", text: "今天外面有点热，出门记得防晒，也别忘了补水。"),
        Message(id: "weather.hot.care.2", text: "现在外面天气偏热，出门记得防晒、补水。"),
    ]

    static let rainyWeatherCare = [
        Message(id: "weather.rain.care.1", text: "现在外面在下雨，如果还要出门，记得带伞，路上慢一点。"),
        Message(id: "weather.rain.care.2", text: "外面正在下雨，如果还要出门，带好伞，路上慢一点。"),
    ]

    static let coldWeatherCare = [
        Message(id: "weather.cold.care.1", text: "现在外面天气偏冷，出门记得添件衣服。"),
        Message(id: "weather.cold.care.2", text: "外面有点冷，如果还要出门，记得添衣。"),
    ]

    static let snowyWeatherCare = [
        Message(id: "weather.snow.care.1", text: "现在外面可能有雪，如果还要出门，注意脚下。"),
        Message(id: "weather.snow.care.2", text: "外面有雪的话，出门注意脚下，路上慢一点。"),
    ]

    static let weatherHint = [
        Message(id: "weather.hint.1", text: "开启天气后，雨天和降温可以多留一层当天信息。"),
        Message(id: "weather.hint.2", text: "允许获取天气后，记录可以保留当时的天气。"),
    ]

    static func personalized(_ message: Message, settings: AppSettings) -> Message {
        let name = settings.petNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return Message(
            id: message.id,
            text: message.text.replacingOccurrences(of: "{petName}", with: name.isEmpty ? "小窝" : name)
        )
    }
}
