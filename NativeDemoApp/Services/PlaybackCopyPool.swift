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
        warm: ["这段时间已经有几笔可以回看的记录。"],
        plain: ["这段时间已经有几笔可以回看的记录。"]
    )

    private static let groups: [String: PlaybackCopyGroup] = [
        "week-intro": PlaybackCopyGroup(
            warm: [
                "这一周，你留下了 {count} 笔记录，合计 {total}。",
                "{petName}收拢了这一周：{count} 笔，{total}。",
                "先把 {rangeLabel} 拢在一起，{count} 笔，{total}，从这里叙起。",
                "{count} 笔记录，{total}；这一周从这里说起。"
            ],
            plain: [
                "这周留下了 {count} 笔记录。",
                "{rangeLabel} 这段时间，可以从 {count} 笔记录说起。",
                "这一周有 {count} 笔可回看的记录。",
                "先把这一周打开看看。"
            ]
        ),
        "week-weak-intro": PlaybackCopyGroup(
            warm: [
                "还只有 {count} 笔，但这一周已经有了开头。",
                "{count} 笔也是开始，{total}，{petName}先帮你留住。",
                "记录还不多，先把 {total} 收下来。"
            ],
            plain: [
                "{count} 笔也是一个开头。",
                "这周刚留下几笔记录。",
                "记录还不多，但已经可以先看一眼。"
            ]
        ),
        "week-rhythm": PlaybackCopyGroup(
            warm: [
                "{busiestDay} 最热闹；{quietestDay} 很轻，这一周一紧一松。",
                "记录集中在 {busiestDay}，{quietestDay} 则很轻，节奏分得开。",
                "{busiestDay} 记录最多，{quietestDay} 相对轻一些。",
                "这一周的起伏，主要落在 {busiestDay} 和 {quietestDay}。"
            ],
            plain: [
                "{busiestDay} 更热闹，{quietestDay} 轻一些。",
                "这一周的起伏，主要落在 {busiestDay} 和 {quietestDay}。",
                "{busiestDay} 记录更多，{quietestDay} 相对少一点。",
                "这一周不是一条直线，有热闹也有轻的一天。"
            ]
        ),
        "week-top-category": PlaybackCopyGroup(
            warm: [
                "「{topCategory}」是这周最常出现的一类。",
                "这周「{topCategory}」在记录里更靠前。",
                "翻遍这一周，「{topCategory}」最容易被看见。",
                "这一周，「{topCategory}」出现得更明显。"
            ],
            plain: [
                "「{topCategory}」是这周最常出现的一类。",
                "这周「{topCategory}」在记录里更靠前。",
                "这一周，「{topCategory}」出现得更明显。",
                "翻到这一周，「{topCategory}」最容易被看见。"
            ]
        ),
        "week-highlight": PlaybackCopyGroup(
            warm: [
                "{highlightDayLabel}，记录里有这样一笔：「{highlightTitle}」。",
                "{highlightDayLabel} 这一笔被单独拎出来：「{highlightTitle}」。",
                "这一周有一笔较醒目：「{highlightTitle}」。",
                "本周的单笔片段落在 {highlightDayLabel}：「{highlightTitle}」。"
            ],
            plain: [
                "{highlightDayLabel} 这一笔：「{highlightTitle}」。",
                "这一笔「{highlightTitle}」被单独列出来。",
                "这一周有一笔：「{highlightTitle}」。",
                "{highlightDayLabel} 的「{highlightTitle}」留在记录里。"
            ]
        ),
        "week-outro": PlaybackCopyGroup(
            warm: [
                "这一周先讲到这里。下周有新记录，再回来听。",
                "这一周的回放到这里；下个自然周再看新的版本。",
                "先把这一周放在这里。下周见，{petName}还在。",
                "这一周到这儿。下一周有了新记录，再来听新版。"
            ],
            plain: [
                "这一周先叙到这里。",
                "下个自然周，再来听新的这一周。",
                "这一周已经留在记录里。",
                "先把这一周放在这里。"
            ]
        ),
        "week-weak-outro": PlaybackCopyGroup(
            warm: [
                "再多记几笔，下一遍会更像你的这一周。",
                "{petName}等你把这一周记满，再来叙完整版。",
                "补几笔日常，下次回放会更完整。"
            ],
            plain: [
                "再多记几笔，下一遍会更像你的这一周。",
                "等这一周更完整一点，再回来听。",
                "先留住这个开头，后面会更立体。"
            ]
        ),
        "month-intro": PlaybackCopyGroup(
            warm: [
                "{rangeLabel}，{activeDays} 天有记录，{count} 笔，一共 {total}。",
                "{petName}收下 {rangeLabel}：{count} 笔、{activeDays} 个记录日，合计 {total}。",
                "这个月你来了 {activeDays} 天，留下 {count} 笔，{total}。",
                "先把 {rangeLabel} 拢在一起：{activeDays} 天、{count} 笔、{total}。"
            ],
            plain: [
                "{rangeLabel} 有 {activeDays} 天留下了记录。",
                "这个月来了 {activeDays} 天，留下 {count} 个片段。",
                "先把 {rangeLabel} 打开看看。",
                "这个月的月记，从 {activeDays} 个记录日说起。"
            ]
        ),
        "month-early": PlaybackCopyGroup(
            warm: [
                "上旬先落下 {earlyCount} 笔记录。",
                "月初这十天，留下了 {earlyCount} 笔。",
                "上旬的记录先把这个月铺开。",
                "前十天，是这个月的开场。"
            ],
            plain: [
                "上旬先落下了 {earlyCount} 笔。",
                "月初这十天，有一点点生活底色。",
                "上旬的记录先把这个月铺开。",
                "前十天，是这个月的开场。"
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
                "这个月的后半段更容易被看见。",
                "中下旬各有自己的节奏。"
            ]
        ),
        "month-composition": PlaybackCopyGroup(
            warm: [
                "「{topCategory}」是这个月最明显的一块拼图。",
                "翻遍 {rangeLabel}，「{topCategory}」站得比较靠前。",
                "生活构成里，「{topCategory}」更靠前。",
                "这个月，「{topCategory}」出现得更明显。"
            ],
            plain: [
                "「{topCategory}」是这个月最明显的一块拼图。",
                "这个月，「{topCategory}」最容易被看见。",
                "生活构成里，「{topCategory}」站得比较靠前。",
                "翻到这个月，「{topCategory}」是一条清楚的线。"
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
                "这个月的节奏已经有轮廓了，想再聊细一点，可以打开月度复盘。",
                "这个月先讲到这里。下个月有新记录，再回来听。",
                "{petName}把 {rangeLabel} 收好；下次再来听新版。",
                "这个月讲完了，下个月见。"
            ],
            plain: [
                "这个月先叙到这里。",
                "这个月已经留在记录里。",
                "下个月，会有新的月记。",
                "这段时间先放在这里。"
            ]
        )
    ]

    private static let weekTeasers = [
        "{busiestDayShort} 最热闹 · {topCategory} 更靠前",
        "这一周，{topCategory} 更常出现",
        "{count} 笔记录，串起这一周",
        "{rangeLabel} · 约半分钟讲完"
    ]

    private static let monthTeasers = [
        "{rangeLabel}里，「{topCategory}」最常被看见",
        "这个月，「{topCategory}」像一条清楚的生活线索",
        "{count} 笔记录，把这个月讲清楚",
        "{rangeLabel}的记录轮廓已经出来了"
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
