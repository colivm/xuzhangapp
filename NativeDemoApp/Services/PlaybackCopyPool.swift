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
        petName: String = "小窝"
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
        warm: ["这段时间已经有几笔记录可以回看。"],
        plain: ["这段时间已经有几笔记录可以回看。"]
    )

    private static let groups: [String: PlaybackCopyGroup] = [
        "week-intro": PlaybackCopyGroup(
            warm: [
                "这一周，你留下了 {count} 笔记录，合计 {total}。",
                "{rangeLabel} 有 {count} 笔记录，合计 {total}。",
                "{rangeLabel} 记下 {count} 笔，合计 {total}。",
                "{count} 笔记录，{total}；这一周从这里看。"
            ],
            plain: [
                "这周留下了 {count} 笔记录。",
                "{rangeLabel} 这段时间，有 {count} 笔记录。",
                "这一周有 {count} 笔可回看的记录。",
                "先看这一周的记录。"
            ]
        ),
        "week-weak-intro": PlaybackCopyGroup(
            warm: [
                "还只有 {count} 笔，但这一周已经有了开头。",
                "{count} 笔也是开始，合计 {total}。",
                "记录还不多，先把这几笔记清楚。"
            ],
            plain: [
                "{count} 笔也是一个开头。",
                "这周刚留下几笔记录。",
                "记录还不多，但已经可以先看一眼。"
            ]
        ),
        "week-rhythm": PlaybackCopyGroup(
            warm: [
                "{busiestDay} 记录更多；{quietestDay} 少一些。",
                "记录集中在 {busiestDay}，{quietestDay} 则很轻，节奏分得开。",
                "{busiestDay} 记录最多，{quietestDay} 相对轻一些。",
                "这一周的起伏，主要落在 {busiestDay} 和 {quietestDay}。"
            ],
            plain: [
                "{busiestDay} 更热闹，{quietestDay} 轻一些。",
                "这一周的起伏，主要落在 {busiestDay} 和 {quietestDay}。",
                "{busiestDay} 记录更多，{quietestDay} 相对少一点。",
                "这一周每天不太一样。"
            ]
        ),
        "week-top-category": PlaybackCopyGroup(
            warm: [
                "「{topCategory}」是这周最常出现的一类。",
                "这周「{topCategory}」在记录里更靠前。",
                "这一周里，「{topCategory}」出现得多一些。",
                "这一周，「{topCategory}」出现得更明显。"
            ],
            plain: [
                "「{topCategory}」是这周最常出现的一类。",
                "这周「{topCategory}」在记录里更靠前。",
                "这一周，「{topCategory}」出现得更明显。",
                "这一周里，「{topCategory}」出现得多一些。"
            ]
        ),
        "week-highlight": PlaybackCopyGroup(
            warm: [
                "{highlightDayLabel}，记录里有这样一笔：「{highlightTitle}」。",
                "{highlightDayLabel} 有一笔：「{highlightTitle}」。",
                "这一周有一笔：「{highlightTitle}」。",
                "{highlightDayLabel} 的记录里有「{highlightTitle}」。"
            ],
            plain: [
                "{highlightDayLabel} 这一笔：「{highlightTitle}」。",
                "这一笔是「{highlightTitle}」。",
                "这一周有一笔：「{highlightTitle}」。",
                "{highlightDayLabel} 的「{highlightTitle}」留在记录里。"
            ]
        ),
        "week-outro": PlaybackCopyGroup(
            warm: [
                "这一周先记到这里。有新记录时，再回来听新的版本。",
                "这周的记录到这里；下个自然周再看新的变化。",
                "这一周先留在记录里。后面多几笔，再回来对照。",
                "这一周到这里。下一周有了新记录，再听新版。"
            ],
            plain: [
                "这些记录先放在这里。",
                "下个自然周，再听新的这一周。",
                "这一周已经在账本里。",
                "之后有新记录，再回来对照。"
            ]
        ),
        "week-weak-outro": PlaybackCopyGroup(
            warm: [
                "再多记几笔，下一遍会更像这一周。",
                "这周还只是开头，后面多几笔再回来听。",
                "补几笔日常，下次回放会更完整。"
            ],
            plain: [
                "再多记几笔，下一遍会更完整。",
                "等这一周记录多一点，再回来听。",
                "先留着这个开头，后面再补。"
            ]
        ),
        "month-intro": PlaybackCopyGroup(
            warm: [
                "{rangeLabel}，{activeDays} 天有记录，{count} 笔，一共 {total}。",
                "{rangeLabel}：{activeDays} 天有记录，{count} 笔，合计 {total}。",
                "这个月有 {activeDays} 天记过账，留下 {count} 笔，{total}。",
                "{rangeLabel} 记下 {activeDays} 个记录日，{count} 笔，{total}。"
            ],
            plain: [
                "{rangeLabel} 有 {activeDays} 天留下了记录。",
                "这个月有 {activeDays} 天留下记录。",
                "先看 {rangeLabel} 的记录。",
                "这个月的月记，从 {activeDays} 个记录日说起。"
            ]
        ),
        "month-early": PlaybackCopyGroup(
            warm: [
                "上旬先落下 {earlyCount} 笔记录。",
                "月初这十天，留下了 {earlyCount} 笔。",
                "上旬先有了记录。",
                "前十天先记下这些。"
            ],
            plain: [
                "上旬先落下了 {earlyCount} 笔。",
                "月初这十天，有几笔记录。",
                "上旬先有了记录。",
                "前十天先记下这些。"
            ]
        ),
        "month-middle-late": PlaybackCopyGroup(
            warm: [
                "中旬和下旬的节奏拉开了一点，{leadingSegment}更热闹。",
                "月中的节奏在中下旬拉开：{leadingSegment}更集中。",
                "{leadingSegment}是本月后半段更明显的一段。",
                "后半月比前半月更活跃，{leadingSegment}尤其明显。"
            ],
            plain: [
                "中旬和下旬的节奏拉开了一点。",
                "{leadingSegment}更热闹一点。",
                "这个月的后半段更清楚一点。",
                "中下旬各有自己的节奏。"
            ]
        ),
        "month-composition": PlaybackCopyGroup(
            warm: [
                "「{topCategory}」是这个月最常出现的一类。",
                "{rangeLabel} 里，「{topCategory}」站得比较靠前。",
                "这个月的记录里，「{topCategory}」更靠前。",
                "这个月，「{topCategory}」出现得更明显。"
            ],
            plain: [
                "「{topCategory}」是这个月最常出现的一类。",
                "这个月，「{topCategory}」出现得更靠前。",
                "这个月的记录里，「{topCategory}」站得比较靠前。",
                "这个月，「{topCategory}」是一条清楚的线。"
            ]
        ),
        "month-change": PlaybackCopyGroup(
            warm: [
                "{changeHint}",
                "若说这个月的一个变化：{changeHint}",
                "{petName}注意到：{changeHint}"
            ],
            plain: [
                "{changeHint}"
            ]
        ),
        "month-action": PlaybackCopyGroup(
            warm: [
                "这个月已经有一些记录。想读细一点，可以打开月度复盘。",
                "这个月先到这里。下个月有新记录，再回来听。",
                "{rangeLabel} 先留在记录里；之后有新记录，再听新版。",
                "这个月到这里。下个月再看新的记录。"
            ],
            plain: [
                "这些记录先留在这个月。",
                "这个月已经在账本里。",
                "下个月，会有新的月记。",
                "这段时间先记到这里。"
            ]
        )
    ]

    private static let weekTeasers = [
        "{busiestDayShort} 最热闹 · {topCategory} 更靠前",
        "这一周，{topCategory} 更常出现",
        "{count} 笔记录，先看这一周",
        "{rangeLabel} · 半分钟回看"
    ]

    private static let monthTeasers = [
        "{rangeLabel}里，「{topCategory}」出现得最多",
        "这个月，「{topCategory}」是一条清楚线索",
        "{count} 笔记录，先看这个月",
        "{rangeLabel}的记录已经攒下一些"
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
        return trimmed.isEmpty ? "小窝" : trimmed
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
