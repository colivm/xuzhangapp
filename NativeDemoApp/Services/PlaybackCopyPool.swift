import Foundation

private struct PlaybackCopyGroup {
    let warm: [String]
    let plain: [String]
}

enum PlaybackCopyPool {
    static func narration(
        chapterId: String,
        seed: String,
        values: [String: String],
        petName: String = "小獭"
    ) -> SummaryNarration {
        let group = groups[chapterId] ?? fallbackGroup
        let merged = values.merging(["petName": normalizedPetName(petName)]) { current, _ in current }
        return SummaryNarration(
            warm: render(pick(group.warm, seed: "\(seed)|\(chapterId)|warm"), values: merged),
            plain: render(pick(group.plain, seed: "\(seed)|\(chapterId)|plain"), values: merged)
        )
    }

    static func teaser(seed: String, values: [String: String]) -> String {
        weekTeaser(seed: seed, values: values)
    }

    static func weekTeaser(seed: String, values: [String: String]) -> String {
        render(pick(weekTeasers, seed: seed), values: values)
    }

    static func monthTeaser(seed: String, values: [String: String]) -> String {
        render(pick(monthTeasers, seed: seed), values: values)
    }

    private static let fallbackGroup = PlaybackCopyGroup(
        warm: ["{mainLine}"],
        plain: ["{mainLine}"]
    )

    private static let factualGroup = PlaybackCopyGroup(
        warm: ["{mainLine}"],
        plain: ["{mainLine}"]
    )

    private static let groups: [String: PlaybackCopyGroup] = Dictionary(
        uniqueKeysWithValues: [
            "week-presence",
            "week-weak-presence",
            "week-rhythm",
            "week-voices",
            "week-weak-voices",
            "week-scent",
            "week-outro",
            "week-weak-outro",
            "month-opening",
            "month-early-voice",
            "month-late-voice",
            "month-change",
            "month-scent",
            "month-outro"
        ].map { ($0, factualGroup) }
    )

    private static let weekTeasers = ["{teaserLine}"]

    private static let monthTeasers = ["{teaserLine}"]

    private static func render(_ template: String, values: [String: String]) -> String {
        values.reduce(template) { result, pair in
            result.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
        }
    }

    private static func pick(_ templates: [String], seed: String) -> String {
        guard !templates.isEmpty else { return "" }
        return templates[stableIndex(seed: seed, count: templates.count)]
    }

    private static func normalizedPetName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "小獭" : trimmed
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
