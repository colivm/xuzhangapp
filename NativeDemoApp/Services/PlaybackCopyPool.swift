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
        warm: ["这段生活先留在这里。"],
        plain: ["这段生活先留在这里。"]
    )

    private static let groups: [String: PlaybackCopyGroup] = [
        "week-presence": PlaybackCopyGroup(
            warm: [
                "{rangeLabel} 先不急着看成一张表，可以按几段记录来回看。",
                "这一周的开场，不在合计里，而在「{voiceTitle1}」这样的片段里。",
                "{lifeMarkLine}"
            ],
            plain: [
                "{rangeLabel} 先从生活片段看起。",
                "这一周从「{voiceTitle1}」开始回看。",
                "{lifeMarkLine}"
            ]
        ),
        "week-weak-presence": PlaybackCopyGroup(
            warm: [
                "这周还只是几格，但已经能看见一点生活的开头。",
                "先把这几笔放在同一段里听一遍，不急着下结论。",
                "这周的胶片还短，先留住「{voiceTitle1}」这一格。"
            ],
            plain: [
                "这周先留住这几格。",
                "先从「{voiceTitle1}」听起。",
                "记录还少，但生活已经有了开头。"
            ]
        ),
        "week-rhythm": PlaybackCopyGroup(
            warm: [
                "{busiestDay} 记录更多，其中包括「{busiestTitle}」。",
                "{busiestDay} 记录最多，其中一笔是「{busiestTitle}」。",
                "{sceneMemoryLine}"
            ],
            plain: [
                "{busiestDay} 这一格里，有「{busiestTitle}」。",
                "这一周可以记住 {busiestDay} 的「{busiestTitle}」。",
                "{sceneMemoryLine}"
            ]
        ),
        "week-voices": PlaybackCopyGroup(
            warm: [
                "如果只能留下一句，这周会先留下「{voiceTitle1}」。",
                "这一周可以先看「{voiceTitle1}」这笔记录。",
                "这一周最具体的一格，是「{voiceTitle1}」。"
            ],
            plain: [
                "这周先记住「{voiceTitle1}」。",
                "账本里留下了「{voiceTitle1}」这一句。",
                "这一周可以从「{voiceTitle1}」想起。"
            ]
        ),
        "week-weak-voices": PlaybackCopyGroup(
            warm: [
                "目前最清楚的一格，是「{voiceTitle1}」。",
                "记录还少，但「{voiceTitle1}」已经能把这周留住一点。",
                "短短几笔里，「{voiceTitle1}」先露了出来。"
            ],
            plain: [
                "先记住「{voiceTitle1}」。",
                "这几笔里有「{voiceTitle1}」。",
                "记录不多，但这一句已经够具体。"
            ]
        ),
        "week-scent": PlaybackCopyGroup(
            warm: [
                "这一周反复出现的是：{scentWords}。",
                "把金额先放到一边，{scentWords} 才是这周更有味道的部分。",
                "{lifeMarkTitle} 也在这一周的记录里。"
            ],
            plain: [
                "这一周可以用 {scentWords} 来想起。",
                "{scentWords} 在这周反复出现。",
                "{lifeMarkLine}"
            ]
        ),
        "week-outro": PlaybackCopyGroup(
            warm: [
                "这一周先收在这里。以后再回来，看的不是合计，是这些片段怎么连成了生活。",
                "这些句子先放回账本里。下次再听，会接上新的天气、新的路和新的饭点。",
                "这一周已经留下来了，不必讲满，能被想起就够了。"
            ],
            plain: [
                "这周先收在这里。",
                "这些片段先放回账本里。",
                "下周再接着听新的生活。"
            ]
        ),
        "week-weak-outro": PlaybackCopyGroup(
            warm: [
                "这周先记录到这里。再多几笔，回看时会更完整。",
                "先到这里，不急着讲大道理；几格也能证明这周真实发生过。",
                "先留住这一小段，下次回来会有更多能接上的镜头。"
            ],
            plain: [
                "先留住这个开头。",
                "这周先到这里。",
                "再多几笔，下次会更完整。"
            ]
        ),
        "month-opening": PlaybackCopyGroup(
            warm: [
                "{rangeLabel} 不该只被压成一个总数，先从「{voiceTitle1}」这一格看起。",
                "这个月的第一句，不是花了多少，而是「{voiceTitle1}」。",
                "{lifeMarkLine}"
            ],
            plain: [
                "{rangeLabel} 先看「{voiceTitle1}」。",
                "这个月先从「{voiceTitle1}」听起。",
                "{lifeMarkLine}"
            ]
        ),
        "month-early-voice": PlaybackCopyGroup(
            warm: [
                "月初那几天，先记下来的是「{earlyVoiceTitle}」。",
                "这个月刚展开时，「{earlyVoiceTitle}」先占了一格。",
                "前十天不用讲得很满，记住「{earlyVoiceTitle}」就有画面。"
            ],
            plain: [
                "月初留下了「{earlyVoiceTitle}」。",
                "前十天先记住「{earlyVoiceTitle}」。",
                "上旬这一格是「{earlyVoiceTitle}」。"
            ]
        ),
        "month-late-voice": PlaybackCopyGroup(
            warm: [
                "这个月往后走，又换成了「{lateVoiceTitle}」这样的画面。",
                "到了后半段，账本里多了一句「{lateVoiceTitle}」。",
                "中下旬没有只是在延续，它留下了「{lateVoiceTitle}」这个侧面。"
            ],
            plain: [
                "后半月留下了「{lateVoiceTitle}」。",
                "中下旬这一格是「{lateVoiceTitle}」。",
                "这个月后面可以记住「{lateVoiceTitle}」。"
            ]
        ),
        "month-change": PlaybackCopyGroup(
            warm: [
                "{changeHint}",
                "这个月的变化主要是：{changeHint}",
                "{petName} 看到的记录变化是：{changeHint}"
            ],
            plain: [
                "{changeHint}",
                "这个月可以记住这个变化：{changeHint}",
                "这一段的变化是：{changeHint}"
            ]
        ),
        "month-scent": PlaybackCopyGroup(
            warm: [
                "这个月反复出现的是：{scentWords}。",
                "把这个月拆成镜头，{scentWords} 会一次次回来。",
                "{rangeLabel} 的气味，藏在 {scentWords} 和「{lifeMarkTitle}」里。"
            ],
            plain: [
                "这个月可以用 {scentWords} 来想起。",
                "{scentWords} 在这个月反复回来。",
                "{rangeLabel} 里，有「{lifeMarkTitle}」这条线。"
            ]
        ),
        "month-outro": PlaybackCopyGroup(
            warm: [
                "这个月先收到这里。以后再翻回来，可以先看记录，再看金额。",
                "{rangeLabel} 先放回账本里。下个月会有新的天气、新的路线和新的记录。",
                "这一个月已经记录下来，下个月会有新的记录。"
            ],
            plain: [
                "这个月先收到这里。",
                "{rangeLabel} 先放回账本里。",
                "下个月再听新的生活。"
            ]
        )
    ]

    private static let weekTeasers = [
        "{busiestDayShort} 那一格，留下过「{voiceTitle1}」。",
        "这一周，可以从「{voiceTitle1}」听起。",
        "这周反复出现：{scentWords}。",
        "{lifeMarkLine}"
    ]

    private static let monthTeasers = [
        "{rangeLabel}，先记住「{voiceTitle1}」。",
        "{changeHint}",
        "这个月反复出现：{scentWords}。",
        "{lifeMarkLine}"
    ]

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
