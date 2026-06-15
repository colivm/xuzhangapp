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
        warm: ["这段记录先留在这里。"],
        plain: ["这段记录先留在这里。"]
    )

    private static let groups: [String: PlaybackCopyGroup] = [
        "week-presence": PlaybackCopyGroup(
            warm: [
                "{rangeLabel}，这一周已经有一段可回看的生活。",
                "这一周先从这些记录听起。",
                "{rangeLabel} 留下了记录，故事从这里开始。"
            ],
            plain: [
                "{rangeLabel}，这一周已经有记录可回看。",
                "先看这一周留下的记录。",
                "这一周从这里开始回看。"
            ]
        ),
        "week-weak-presence": PlaybackCopyGroup(
            warm: [
                "这周记录还不多，但已经有了开头。",
                "先把这几笔放在这一周里听一遍。",
                "这周刚留下几笔，先听一个短版本。"
            ],
            plain: [
                "这周记录还不多，先听一个短版本。",
                "这几笔先作为这一周的开头。",
                "记录还少，先简单回看。"
            ]
        ),
        "week-rhythm": PlaybackCopyGroup(
            warm: [
                "{busiestDay} 更热闹，代表的一笔是「{busiestTitle}」。",
                "这一周的起伏落在 {busiestDay}，那天留下了「{busiestTitle}」。",
                "{busiestDay} 记录更密一点，其中有「{busiestTitle}」。"
            ],
            plain: [
                "{busiestDay} 记录更多，代表一笔是「{busiestTitle}」。",
                "这一周更集中在 {busiestDay}，那天有「{busiestTitle}」。",
                "{busiestDay} 更忙一点，留下了「{busiestTitle}」。"
            ]
        ),
        "week-voices": PlaybackCopyGroup(
            warm: [
                "这周最像生活句的，是「{voiceTitle1}」。",
                "账本里有一句「{voiceTitle1}」，比数字更有画面。",
                "这一周留下的话里，「{voiceTitle1}」站得出来。"
            ],
            plain: [
                "这周有一句「{voiceTitle1}」。",
                "账本里留下了「{voiceTitle1}」。",
                "这一周可以从「{voiceTitle1}」记起。"
            ]
        ),
        "week-weak-voices": PlaybackCopyGroup(
            warm: [
                "目前能读到的一句是「{voiceTitle1}」。",
                "记录还少，但「{voiceTitle1}」已经能留下来。",
                "短短几笔里，有「{voiceTitle1}」。"
            ],
            plain: [
                "目前能读到的一句是「{voiceTitle1}」。",
                "这几笔里有「{voiceTitle1}」。",
                "记录不多，先记住「{voiceTitle1}」。"
            ]
        ),
        "week-scent": PlaybackCopyGroup(
            warm: [
                "这周常冒头的词是：{scentWords}。",
                "把标题和标记拆开看，{scentWords} 反复出现。",
                "这一周的气味不在大数字里，而在 {scentWords}。"
            ],
            plain: [
                "这周常出现的词是：{scentWords}。",
                "标题和标记里，{scentWords} 更常见。",
                "这一周可以用 {scentWords} 来记。"
            ]
        ),
        "week-outro": PlaybackCopyGroup(
            warm: [
                "这周先记到这里，下周再听新的版本。",
                "这些句子先放回账本里，下周再接着听。",
                "这一周已经留下来了，后面有新记录再回来。"
            ],
            plain: [
                "这周先记到这里。",
                "这些记录先放回账本里。",
                "下周再听新的版本。"
            ]
        ),
        "week-weak-outro": PlaybackCopyGroup(
            warm: [
                "再多记几笔，下次会更像完整的一周。",
                "这周先到这里，后面多一点记录会更清楚。",
                "先留住这个开头，下次再听更完整。"
            ],
            plain: [
                "再多记几笔，下次会更完整。",
                "这周先到这里。",
                "先留住这个开头。"
            ]
        ),
        "month-opening": PlaybackCopyGroup(
            warm: [
                "{rangeLabel} 有 {activeDays} 天留下了记录，先从一句「{voiceTitle1}」听起。",
                "这个月不是一张表，先记住「{voiceTitle1}」。",
                "{rangeLabel} 的开头，落在「{voiceTitle1}」这样的记录里。"
            ],
            plain: [
                "{rangeLabel} 有 {activeDays} 天留下记录，先看「{voiceTitle1}」。",
                "这个月先从「{voiceTitle1}」听起。",
                "{rangeLabel} 先记住「{voiceTitle1}」。"
            ]
        ),
        "month-early-voice": PlaybackCopyGroup(
            warm: [
                "上旬留下的一句是「{earlyVoiceTitle}」。",
                "月初先落下一笔「{earlyVoiceTitle}」。",
                "前十天里，「{earlyVoiceTitle}」先站出来。"
            ],
            plain: [
                "上旬有「{earlyVoiceTitle}」。",
                "月初留下了「{earlyVoiceTitle}」。",
                "前十天里有「{earlyVoiceTitle}」。"
            ]
        ),
        "month-late-voice": PlaybackCopyGroup(
            warm: [
                "中下旬换了一个侧面：「{lateVoiceTitle}」。",
                "到了后半月，记录里出现了「{lateVoiceTitle}」。",
                "这个月往后走，留下了「{lateVoiceTitle}」。"
            ],
            plain: [
                "中下旬有「{lateVoiceTitle}」。",
                "后半月留下了「{lateVoiceTitle}」。",
                "这个月后面出现了「{lateVoiceTitle}」。"
            ]
        ),
        "month-change": PlaybackCopyGroup(
            warm: [
                "{changeHint}",
                "这个月有一个变化点：{changeHint}",
                "{petName} 注意到：{changeHint}"
            ],
            plain: [
                "{changeHint}",
                "这个月的变化点是：{changeHint}",
                "可以记住这个变化：{changeHint}"
            ]
        ),
        "month-scent": PlaybackCopyGroup(
            warm: [
                "这个月常冒头的词是：{scentWords}。",
                "把这个月拆成词，{scentWords} 更常回来。",
                "{rangeLabel} 的气味，藏在 {scentWords} 里。"
            ],
            plain: [
                "这个月常出现的词是：{scentWords}。",
                "这个月可以用 {scentWords} 来记。",
                "{rangeLabel} 里，{scentWords} 更常见。"
            ]
        ),
        "month-outro": PlaybackCopyGroup(
            warm: [
                "这个月先收到这里，下个月再听新的生活句。",
                "{rangeLabel} 先放回账本里，下个月会有新的版本。",
                "这一个月已经留下来了，下一章等新记录长出来。"
            ],
            plain: [
                "这个月先收到这里。",
                "{rangeLabel} 先放回账本里。",
                "下个月再听新的版本。"
            ]
        )
    ]

    private static let weekTeasers = [
        "{busiestDayShort} 更热闹，留下过「{voiceTitle1}」。",
        "这一周，可以从「{voiceTitle1}」听起。",
        "这周常冒头的是 {scentWords}。",
        "{rangeLabel} 留下了「{voiceTitle1}」。"
    ]

    private static let monthTeasers = [
        "{rangeLabel}，先记住「{voiceTitle1}」。",
        "这个月的变化点：{changeHint}",
        "{rangeLabel} 常冒头的是 {scentWords}。",
        "这个月可以从「{voiceTitle1}」听起。"
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
