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
        Message(id: "day.empty.1", text: "今天还没记账，也不用硬凑。"),
        Message(id: "day.empty.2", text: "今天还没有记录，想起一笔再写。"),
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
