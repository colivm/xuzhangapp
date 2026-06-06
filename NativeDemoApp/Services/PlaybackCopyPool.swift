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
        render(pick(teasers, seed: seed), values: values)
    }

    private static let fallbackGroup = PlaybackCopyGroup(
        warm: ["这段时间已经留下了可以回看的生活痕迹。"],
        plain: ["本段生活切片已生成。"]
    )

    private static let groups: [String: PlaybackCopyGroup] = [
        "week-intro": PlaybackCopyGroup(
            warm: [
                "这一周，你留下了 {count} 笔小痕迹，合计 {total}。",
                "{petName}收拢了这一周：{count} 笔，{total}。",
                "先把 {rangeLabel} 拢在一起，{count} 笔，{total}，从这里叙起。",
                "{count} 笔小记录，{total}；这一周的故事，开始讲了。"
            ],
            plain: [
                "{rangeLabel}：{count} 笔，支出 {total}。",
                "本周 {count} 笔，合计 {total}。",
                "{count} 笔 · {total}（{rangeLabel}）。",
                "周期内 {count} 笔记录，总支出 {total}。"
            ]
        ),
        "week-weak-intro": PlaybackCopyGroup(
            warm: [
                "还只有 {count} 笔，但这一周已经有了开头。",
                "{count} 笔也是开始，{total}，{petName}先帮你留住。",
                "记录还不多，先把 {total} 收下来。"
            ],
            plain: [
                "{count} 笔，{total}（数据较少）。",
                "本周 {count} 笔记录。",
                "记录偏少：{count} 笔。"
            ]
        ),
        "week-rhythm": PlaybackCopyGroup(
            warm: [
                "{busiestDay} 最热闹；{quietestDay} 很轻，这一周一紧一松。",
                "支出集中在 {busiestDay}，{quietestDay} 则很轻，节奏分得开。",
                "{busiestDay} 花得最多；{quietestDay} 像刻意留白。",
                "若把这一周拉成曲线：{busiestDay} 是峰，{quietestDay} 是谷。"
            ],
            plain: [
                "支出高峰：{busiestDay}；最低：{quietestDay}。",
                "{busiestDay} 笔数/金额最高，{quietestDay} 最低。",
                "集中日 {busiestDay}，轻量日 {quietestDay}。",
                "本周波动：{busiestDay} → {quietestDay}。"
            ]
        ),
        "week-top-category": PlaybackCopyGroup(
            warm: [
                "「{topCategory}」占了这周的多数，约 {ratio}%。",
                "大约 {ratio}% 在「{topCategory}」，这周的生活配方里，它站 C 位。",
                "翻遍这一周，「{topCategory}」出现最勤，约 {ratio}%。",
                "{ratio}% 落在「{topCategory}」上，像这一周的底色。"
            ],
            plain: [
                "「{topCategory}」约占 {ratio}%。",
                "TOP1：{topCategory}（{ratio}%）。",
                "{topCategory}：{ratio}% 占比。",
                "最高分类 {topCategory}，{ratio}%。"
            ]
        ),
        "week-highlight": PlaybackCopyGroup(
            warm: [
                "{highlightDayLabel}，你为自己留了这样一笔：「{highlightTitle}」。",
                "若选本周一笔来代表心情，{petName}会投给「{highlightTitle}」。",
                "{highlightDayLabel} 这一笔最有画面感：「{highlightTitle}」。",
                "本周的高光落在 {highlightDayLabel}：「{highlightTitle}」。"
            ],
            plain: [
                "单笔代表：{highlightTitle}（{highlightDayLabel}，{highlightAmount}）。",
                "本周最高单笔：{highlightAmount}，{highlightTitle}。",
                "高光：{highlightTitle} · {highlightAmount}。",
                "{highlightDayLabel}：{highlightTitle}，{highlightAmount}。"
            ]
        ),
        "week-outro": PlaybackCopyGroup(
            warm: [
                "这一遍先叙到这里。下周再记几天，{petName}准时来接新的一周。",
                "这一周的故事讲完了；下个自然周，再来叙新的一章。",
                "先收下这一遍回看。下周见，{petName}还在。",
                "周切片到这儿。下一周有了新记录，再来听新版。"
            ],
            plain: [
                "本周切片结束，下周可再看。",
                "周度回放完成。",
                "本周生活切片已播完。",
                "结束；下个自然周更新。"
            ]
        ),
        "week-weak-outro": PlaybackCopyGroup(
            warm: [
                "再多记几笔，下一遍会更像你的这一周。",
                "{petName}等你把这一周记满，再来叙完整版。",
                "补几笔日常，下次切片会更立体。"
            ],
            plain: [
                "记录较少，补充后可生成更完整切片。",
                "建议增加记录后再播放。",
                "数据不足，完整 5 幕需 ≥3 笔。"
            ]
        ),
        "month-intro": PlaybackCopyGroup(
            warm: [
                "{rangeLabel}，{activeDays} 天有生活痕迹，{count} 笔，一共 {total}。",
                "{petName}收下 {rangeLabel}：{count} 笔、{activeDays} 个记录日，合计 {total}。",
                "这个月你来了 {activeDays} 天，留下 {count} 笔，{total}。",
                "先把 {rangeLabel} 拢在一起：{activeDays} 天、{count} 笔、{total}。"
            ],
            plain: [
                "{rangeLabel}：{count} 笔，{activeDays} 天，{total}。",
                "本月 {count} 笔 / {activeDays} 记录日 / {total}。",
                "{activeDays} 天有账，合计 {total}。",
                "月总览：{count} 笔，{total}。"
            ]
        ),
        "month-early": PlaybackCopyGroup(
            warm: [
                "上旬 {earlyCount} 笔，{earlyAmount}，像月初慢慢铺开的底色。",
                "月初这十天：{earlyCount} 笔、{earlyAmount}，节奏偏稳。",
                "上旬先落下 {earlyCount} 笔，合计 {earlyAmount}。",
                "前十天记了 {earlyCount} 笔，{earlyAmount}，为这个月定调。"
            ],
            plain: [
                "上旬 {earlyCount} 笔，{earlyAmount}。",
                "1-10 日：{earlyAmount}。",
                "上旬支出 {earlyAmount}。",
                "上旬 {earlyCount} 笔。"
            ]
        ),
        "month-middle-late": PlaybackCopyGroup(
            warm: [
                "中旬 {midAmount}，下旬 {lateAmount}；{leadingSegment}更热闹一点。",
                "月中的节奏在中下旬拉开：{leadingSegment}支出更集中。",
                "中旬 {midAmount}、下旬 {lateAmount}，{leadingSegment}是本月的小高峰。",
                "后半月比前半月更活跃，{leadingSegment}尤其明显。"
            ],
            plain: [
                "中旬 {midAmount}，下旬 {lateAmount}。",
                "中下旬对比：{midAmount} / {lateAmount}。",
                "最高旬段：{leadingSegment}。",
                "中 {midAmount} · 下 {lateAmount}。"
            ]
        ),
        "month-composition": PlaybackCopyGroup(
            warm: [
                "「{topCategory}」约占 {ratio}%，是这个月最明显的一块拼图。",
                "翻遍 {rangeLabel}，「{topCategory}」站 C 位，约 {ratio}%。",
                "生活配方里，「{topCategory}」约 {ratio}%，仍是主角。",
                "{ratio}% 落在「{topCategory}」，这一月的底色很清楚。"
            ],
            plain: [
                "{topCategory}：{ratio}%。",
                "本月 TOP1 {topCategory}（{ratio}%）。",
                "最高分类 {topCategory}。",
                "{topCategory} 占比 {ratio}%。"
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
                "生活章先叙到这里。下个月的新记录，会生成新的一章。",
                "{petName}把 {rangeLabel} 收好；下次再来听新版。",
                "这一章讲完了，下个月见。"
            ],
            plain: [
                "本月生活章已生成。",
                "月章播放结束。",
                "可继续查看月度复盘。",
                "本月切片完成。"
            ]
        )
    ]

    private static let teasers = [
        "{busiestDayShort} 支出最多 · {topCategory} 约 {ratio}%",
        "这一周，{topCategory} 是主角",
        "{count} 笔 · {total} · {topCategory} 为主",
        "{rangeLabel} · 约半分钟讲完"
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
