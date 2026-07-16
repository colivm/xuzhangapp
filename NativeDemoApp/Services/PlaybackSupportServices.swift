import Foundation

enum PlaybackMaterialScoring {
    static func stableScore(item: HomeItem, periodKey: String, now: Date) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in "\(item.id.uuidString)|\(periodKey)|\(Int(now.timeIntervalSince1970 / 86_400))".utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % 7)
    }
}

enum ExperienceRuleCopy {
    static func quotaText(remaining: Int, limit: Int) -> String {
        "\(min(limit, max(0, remaining)))/\(limit)"
    }

    static func todayPlaybackFirstUseMessage(remaining: Int) -> String {
        "它会把今天已经记下的几笔照着发生顺序翻一遍。免费用户每天可听 \(DailyFeatureQuotaStore.todayPlaybackFreeLimit) 次，当前剩余 \(quotaText(remaining: remaining, limit: DailyFeatureQuotaStore.todayPlaybackFreeLimit)) 次；白天可以先继续记，晚上记录差不多了再回看，会更完整。"
    }

    static func todayPlaybackExhaustedMessage(remaining: Int = 0) -> String {
        "今日免费回放剩余 \(quotaText(remaining: remaining, limit: DailyFeatureQuotaStore.todayPlaybackFreeLimit)) 次，明天会自动刷新。今天还可以继续记账，晚一点记录更完整时再回看也很好。"
    }

    static func todayPlaybackUsageHint(remaining: Int) -> String {
        "适合晚上回看；今日免费回放剩余 \(quotaText(remaining: remaining, limit: DailyFeatureQuotaStore.todayPlaybackFreeLimit)) 次。"
    }

    static func todayPlaybackActionSubtitle(remaining: Int) -> String {
        "十几秒叙完今天 · 剩余 \(quotaText(remaining: remaining, limit: DailyFeatureQuotaStore.todayPlaybackFreeLimit))"
    }

    static func summaryQuotaFootnote(
        range: SummaryPlaybackRange,
        remaining: Int,
        hasData: Bool,
        isMember: Bool
    ) -> String {
        guard hasData else { return "周记和月章使用本地规则生成，不联网。" }
        guard !isMember else { return "会员可无限回看周记和月章。" }
        switch range {
        case .week:
            let text = quotaText(remaining: remaining, limit: SummaryPlaybackQuotaStore.weeklyFreeLimit)
            return remaining > 0
                ? "周记本周剩余 \(text) 次 · 会员可连续整理周记和月章"
                : "周记本周剩余 \(text) 次 · 下个自然周刷新"
        case .month:
            let text = quotaText(remaining: remaining, limit: SummaryPlaybackQuotaStore.lifetimeMonthFreeLimit)
            return "月章体验剩余 \(text) 次 · 会员可继续整理更多月份"
        }
    }

    static func summaryQuotaExhaustedMessage(range: SummaryPlaybackRange) -> String {
        switch range {
        case .week:
            return "周记本周剩余 \(quotaText(remaining: 0, limit: SummaryPlaybackQuotaStore.weeklyFreeLimit)) 次。下个自然周会刷新。会员可以连续整理周记和月章。"
        case .month:
            return "月章体验剩余 \(quotaText(remaining: 0, limit: SummaryPlaybackQuotaStore.lifetimeMonthFreeLimit)) 次。月章额度不是每月刷新。会员可以继续整理更多月份。"
        }
    }

    static var shareThemeMemberHint: String {
        "会员专属：免费版仍可保存默认风格分享图；开通后，分享图会跟随当前主题配色。"
    }

    static var shareThemeMemberToast: String {
        "分享图使用当前主题是会员专属。免费版可继续保存默认风格，开通后会跟随当前外观配色。"
    }

    static func ocrQuotaExhaustedMessage(remaining: Int = 0) -> String {
        "今日免费账单识别剩余 \(quotaText(remaining: remaining, limit: DailyFeatureQuotaStore.ocrDailyFreeLimit)) 次。你仍可以手动记账；会员适合经常导入截图的人，不用被次数打断。"
    }

    static func ocrSuccessMessage(prefix: String, remaining: Int, isMember: Bool) -> String {
        guard !isMember else {
            return "\(prefix)。会员 OCR 不限次。"
        }
        return "\(prefix)。今日免费账单识别剩余 \(quotaText(remaining: remaining, limit: DailyFeatureQuotaStore.ocrDailyFreeLimit)) 次；会员可连续导入，不用算次数。"
    }

    static var ocrUpsellHeadline: String {
        "今日免费导入已用完"
    }

    static var ocrUpsellDetail: String {
        "今日剩余 0/\(DailyFeatureQuotaStore.ocrDailyFreeLimit) 次，明天会刷新。经常导入微信/支付宝截图的话，会员可连续整理，不用被次数打断。"
    }

    static var ocrUpsellCTA: String {
        "开通会员，连续导入"
    }
}

enum LifeStoryVisualProfile: String, Equatable {
    case rain
    case travel
    case lateCity
    case warmDaily
    case fitness
    case social
    case defaultSoft

    static func detect(from texts: [String]) -> LifeStoryVisualProfile {
        let merged = texts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !merged.isEmpty else { return .defaultSoft }

        if containsAny(merged, ["雨", "雨天", "下雨", "雨里"]) {
            return .rain
        }
        if containsAny(merged, ["外地", "异地", "出行", "旅行", "高铁", "机票", "酒店", "通勤出行"]) {
            return .travel
        }
        if containsAny(merged, ["深夜", "夜里", "晚上", "晚归", "加班", "回家路上", "夜路", "晚间"]) {
            return .lateCity
        }
        if containsAny(merged, ["健身", "运动", "训练", "跑步", "恢复", "理疗", "康复"]) {
            return .fitness
        }
        if containsAny(merged, ["朋友", "聚餐", "见面", "相聚", "请客", "生日", "家庭聚餐", "周末聚餐"]) {
            return .social
        }
        if containsAny(merged, ["早餐", "咖啡", "奶茶", "午饭", "晚饭", "家里", "周末", "热乎", "吃饭"]) {
            return .warmDaily
        }
        return .defaultSoft
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }
}

struct LifeStorySignal: Equatable {
    enum Kind: Equatable {
        case lifeMark
        case scene
        case scent
        case voice
        case emotion
        case rhythm
        case category
        case activity
    }

    let kind: Kind
    let symbol: String
    let rawText: String
    let label: String
    let priority: Int
    let profile: LifeStoryVisualProfile
}

struct SignalSelectionScorecard: Equatable {
    let distinctiveness: Int
    let imagery: Int
    let emotion: Int
    let continuity: Int
    let shareSafety: Int
    let leadBias: Int

    var total: Int {
        distinctiveness + imagery + emotion + continuity + shareSafety + leadBias
    }
}

struct SignalSelectionChoice: Equatable {
    let signal: LifeStorySignal
    let scorecard: SignalSelectionScorecard

    var totalScore: Int { scorecard.total }
}

struct SignalSelectionPolicyResult: Equatable {
    let primary: SignalSelectionChoice?
    let supports: [SignalSelectionChoice]
    let visualProfile: LifeStoryVisualProfile
}

enum ShareCopyRole: String, Equatable {
    case lifeMark
    case scene
    case emotion
    case voice
    case softFallback
}

enum LifeStorySignalService {
    static func chapterSignals(from chapter: SummaryChapter, limit: Int = 3) -> [LifeStorySignal] {
        var signals: [LifeStorySignal] = []

        if let lifeMark = clean(chapter.metrics["lifeMarkLine"]) {
            signals.append(
                LifeStorySignal(
                    kind: .lifeMark,
                    symbol: "sparkles",
                    rawText: lifeMark,
                    label: compact(lifeMark, prefix: "印记"),
                    priority: 0,
                    profile: LifeStoryVisualProfile.detect(from: [lifeMark])
                )
            )
        }
        if let scene = clean(chapter.metrics["sceneMemoryLine"]) {
            signals.append(
                LifeStorySignal(
                    kind: .scene,
                    symbol: "map",
                    rawText: scene,
                    label: compact(scene, prefix: "场景"),
                    priority: 1,
                    profile: LifeStoryVisualProfile.detect(from: [scene])
                )
            )
        }
        if let scent = clean(chapter.metrics["scentWords"]) {
            let first = scent
                .split(separator: "、")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty } ?? scent
            signals.append(
                LifeStorySignal(
                    kind: .scent,
                    symbol: "text.quote",
                    rawText: first,
                    label: compact(first, prefix: "词"),
                    priority: 2,
                    profile: LifeStoryVisualProfile.detect(from: [first])
                )
            )
        }
        if let voice = voiceTitle(from: chapter) {
            signals.append(
                LifeStorySignal(
                    kind: .voice,
                    symbol: "quote.bubble",
                    rawText: voice,
                    label: compact(voice, prefix: "备注"),
                    priority: 3,
                    profile: LifeStoryVisualProfile.detect(from: [voice])
                )
            )
        }
        if let emotion = meaningfulEmotion(from: chapter.metrics["emotionTag"]) {
            signals.append(
                LifeStorySignal(
                    kind: .emotion,
                    symbol: "heart.text.square",
                    rawText: emotion,
                    label: compact(emotion, prefix: "情绪"),
                    priority: 4,
                    profile: LifeStoryVisualProfile.detect(from: [emotion])
                )
            )
        }
        if let busiest = clean(chapter.metrics["busiestDay"]) {
            signals.append(
                LifeStorySignal(
                    kind: .rhythm,
                    symbol: "calendar",
                    rawText: busiest,
                    label: "\(busiest)更密",
                    priority: 5,
                    profile: .defaultSoft
                )
            )
        }
        if let category = clean(chapter.metrics["category"] ?? chapter.metrics["topCategory"]) {
            signals.append(
                LifeStorySignal(
                    kind: .category,
                    symbol: "chart.pie",
                    rawText: category,
                    label: category,
                    priority: 6,
                    profile: LifeStoryVisualProfile.detect(from: [category])
                )
            )
        }

        var seen = Set<String>()
        return signals
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority { return lhs.label < rhs.label }
                return lhs.priority < rhs.priority
            }
            .filter { signal in
                guard !seen.contains(signal.label) else { return false }
                seen.insert(signal.label)
                return true
            }
            .prefix(limit)
            .map { $0 }
    }

    static func weeklyShareSignals(from payload: WeeklyShareCardPayload, limit: Int = 4) -> [LifeStorySignal] {
        var signals: [LifeStorySignal] = []

        if let lifeMark = clean(payload.lifeMarkLine ?? payload.subtitle) {
            signals.append(
                LifeStorySignal(
                    kind: .lifeMark,
                    symbol: "sparkles",
                    rawText: lifeMark,
                    label: compact(lifeMark, prefix: "印记"),
                    priority: 0,
                    profile: LifeStoryVisualProfile.detect(from: [lifeMark])
                )
            )
        }

        if let context = clean(payload.contextLine ?? payload.anchorLine) {
            signals.append(
                LifeStorySignal(
                    kind: .scene,
                    symbol: "map",
                    rawText: context,
                    label: compact(context, prefix: "场景"),
                    priority: 1,
                    profile: LifeStoryVisualProfile.detect(from: [context])
                )
            )
        }

        if let emotion = meaningfulEmotion(from: payload.emotionLine) {
            signals.append(
                LifeStorySignal(
                    kind: .emotion,
                    symbol: "heart.text.square",
                    rawText: emotion,
                    label: compact(emotion, prefix: "情绪"),
                    priority: 2,
                    profile: LifeStoryVisualProfile.detect(from: [emotion])
                )
            )
        }

        if let firstCategory = payload.categorySlices.first {
            let ratio = Int((firstCategory.ratio * 100).rounded())
            let label = "\(firstCategory.label) \(ratio)%"
            signals.append(
                LifeStorySignal(
                    kind: .category,
                    symbol: "chart.pie",
                    rawText: firstCategory.label,
                    label: label,
                    priority: 3,
                    profile: LifeStoryVisualProfile.detect(from: [firstCategory.label])
                )
            )
        }

        let activeDays = max(1, payload.dailyCountTrend.filter { $0.1 > 0 }.count)
        signals.append(
            LifeStorySignal(
                kind: .rhythm,
                symbol: payload.primaryMetricEmoji,
                rawText: "\(activeDays)天有记录",
                label: "\(activeDays)天有记录",
                priority: 4,
                profile: .defaultSoft
            )
        )

        if let firstTag = payload.insight.tags
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "") })
            .first(where: { !$0.isEmpty }) {
            signals.append(
                LifeStorySignal(
                    kind: .activity,
                    symbol: "sparkles",
                    rawText: firstTag,
                    label: compact(firstTag, prefix: "片段"),
                    priority: 5,
                    profile: LifeStoryVisualProfile.detect(from: [firstTag])
                )
            )
        }

        return deduplicated(signals, limit: limit)
    }

    static func selectionPolicy(for playback: SummaryPlayback) -> SignalSelectionPolicyResult {
        selectionPolicy(from: playbackSignals(from: playback))
    }

    static func selectionPolicy(for payload: WeeklyShareCardPayload) -> SignalSelectionPolicyResult {
        selectionPolicy(from: weeklyShareSignals(from: payload, limit: 6))
    }

    static func visualProfile(
        chapter: SummaryChapter?,
        playback: SummaryPlayback,
        memoryLine: String?
    ) -> LifeStoryVisualProfile {
        if let chapter {
            let chapterProfile = selectionPolicy(from: chapterSignals(from: chapter, limit: 5)).visualProfile
            if chapterProfile != .defaultSoft {
                return chapterProfile
            }
        }
        let playbackProfile = selectionPolicy(for: playback).visualProfile
        if playbackProfile != .defaultSoft {
            return playbackProfile
        }
        let chapterTexts = chapter.map {
            [$0.title, $0.narration.plain, $0.narration.warm] + Array($0.metrics.values)
        } ?? []
        return LifeStoryVisualProfile.detect(from: chapterTexts + [playback.title, playback.teaserLine, memoryLine ?? ""])
    }

    static func playbackPrimarySignalLine(from playback: SummaryPlayback) -> String? {
        selectionPolicy(for: playback).primary?.signal.rawText
    }

    static func shareHeadline(from payload: WeeklyShareCardPayload) -> String {
        let selection = selectionPolicy(for: payload)
        if let primary = selection.primary?.signal {
            return outwardShareHeadline(primary: primary, supports: selection.supports.map(\.signal), fallback: payload.insight.fact)
        }
        return payload.insight.fact
    }

    static func sharePictureLine(from payload: WeeklyShareCardPayload) -> String? {
        let selection = selectionPolicy(for: payload)
        guard let primary = selection.primary?.signal else {
            return clean(payload.anchorLine ?? payload.contextLine ?? payload.insight.care)
        }
        return outwardSharePictureLine(primary: primary, supports: selection.supports.map(\.signal), fallback: payload.insight.care)
    }

    static func shareVisualProfile(from payload: WeeklyShareCardPayload) -> LifeStoryVisualProfile {
        let selection = selectionPolicy(for: payload)
        if selection.visualProfile != .defaultSoft {
            return selection.visualProfile
        }
        return LifeStoryVisualProfile.detect(
            from: [
                payload.headline,
                payload.subtitle,
                payload.anchorLine ?? "",
                payload.topCategory,
                payload.insight.fact,
                payload.insight.care
            ] + payload.insight.tags
        )
    }

    static func shareTitleRole(from payload: WeeklyShareCardPayload) -> ShareCopyRole {
        let primary = selectionPolicy(for: payload).primary?.signal
        return shareTitleRole(for: primary)
    }

    static func sharePictureRole(from payload: WeeklyShareCardPayload) -> ShareCopyRole {
        let selection = selectionPolicy(for: payload)
        let primary = selection.primary?.signal
        return sharePictureRole(for: primary, supports: selection.supports.map(\.signal))
    }

    private static func clean(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }

    private static func compact(_ text: String, prefix: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "这段里", with: "")
            .replacingOccurrences(of: "这一周", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let short = cleaned.count > 8 ? "\(cleaned.prefix(8))..." : cleaned
        return "\(prefix)·\(short)"
    }

    private static func voiceTitle(from chapter: SummaryChapter) -> String? {
        ["voiceTitle1", "earlyVoiceTitle", "lateVoiceTitle", "title"]
            .compactMap { chapter.metrics[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func meaningfulEmotion(from raw: String?) -> String? {
        guard let emotion = clean(raw),
              emotion.count >= 2,
              !emotion.contains("日常"),
              !emotion.contains("记录"),
              !emotion.contains("支出") else {
            return nil
        }
        return emotion
    }

    private static func deduplicated(_ signals: [LifeStorySignal], limit: Int) -> [LifeStorySignal] {
        var seen = Set<String>()
        return signals
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority { return lhs.label < rhs.label }
                return lhs.priority < rhs.priority
            }
            .filter { signal in
                guard !seen.contains(signal.label) else { return false }
                seen.insert(signal.label)
                return true
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func playbackSignals(from playback: SummaryPlayback) -> [LifeStorySignal] {
        var pool: [LifeStorySignal] = []
        for chapter in playback.chapters {
            pool.append(contentsOf: chapterSignals(from: chapter, limit: 6))
        }
        return deduplicated(pool, limit: 8)
    }

    private static func selectionPolicy(from signals: [LifeStorySignal]) -> SignalSelectionPolicyResult {
        let ranked = signals
            .map { signal in
                SignalSelectionChoice(signal: signal, scorecard: scorecard(for: signal, allSignals: signals))
            }
            .sorted { lhs, rhs in
                if lhs.totalScore == rhs.totalScore {
                    if lhs.signal.priority == rhs.signal.priority {
                        return lhs.signal.label < rhs.signal.label
                    }
                    return lhs.signal.priority < rhs.signal.priority
                }
                return lhs.totalScore > rhs.totalScore
            }

        let primary = primaryChoice(from: ranked)
        let supports = supportChoices(from: ranked, primary: primary)
        let visualProfile = primary?.signal.profile
            ?? supports.first(where: { $0.signal.profile != .defaultSoft })?.signal.profile
            ?? .defaultSoft
        return SignalSelectionPolicyResult(primary: primary, supports: supports, visualProfile: visualProfile)
    }

    private static func primaryChoice(from ranked: [SignalSelectionChoice]) -> SignalSelectionChoice? {
        guard !ranked.isEmpty else { return nil }

        if let milestoneLead = ranked.first(where: shouldForceLifeMarkLead) {
            return milestoneLead
        }
        if let sceneLead = ranked.first(where: shouldForceSceneLead) {
            return sceneLead
        }
        if let lifeMarkLead = ranked.first(where: preferredLifeMarkLead) {
            return lifeMarkLead
        }
        if let emotionLead = ranked.first(where: preferredEmotionLead) {
            return emotionLead
        }
        if let voiceLead = ranked.first(where: preferredVoiceLead) {
            return voiceLead
        }
        if let humanLead = ranked.first(where: canLeadNarrative) {
            return humanLead
        }
        return ranked.first
    }

    private static func supportChoices(
        from ranked: [SignalSelectionChoice],
        primary: SignalSelectionChoice?
    ) -> [SignalSelectionChoice] {
        let primaryLabel = primary?.signal.label
        let filtered = ranked.filter { choice in
            guard choice.signal.label != primaryLabel else { return false }
            if choice.signal.kind == .rhythm || choice.signal.kind == .category {
                return ranked.filter {
                    $0.signal.label != primaryLabel &&
                    $0.signal.kind != .rhythm &&
                    $0.signal.kind != .category
                }.count < 2
            }
            return true
        }
        return Array(filtered.prefix(3))
    }

    private static func scorecard(for signal: LifeStorySignal, allSignals: [LifeStorySignal]) -> SignalSelectionScorecard {
        let text = signal.rawText
        let hasConcreteSceneSupport = allSignals.contains {
            $0.kind == .scene && $0.profile != .defaultSoft && $0.rawText != signal.rawText
        }
        return SignalSelectionScorecard(
            distinctiveness: distinctivenessScore(for: signal, text: text),
            imagery: imageryScore(for: signal, text: text),
            emotion: emotionScore(for: signal, text: text, hasConcreteSceneSupport: hasConcreteSceneSupport),
            continuity: continuityScore(for: signal, text: text),
            shareSafety: shareSafetyScore(for: signal, text: text),
            leadBias: leadBiasScore(for: signal, text: text, hasConcreteSceneSupport: hasConcreteSceneSupport)
        )
    }

    private static func distinctivenessScore(for signal: LifeStorySignal, text: String) -> Int {
        var score = 1
        if containsAny(text, ["第一次", "重新", "恢复", "终于", "开始", "又"]) { score += 3 }
        if containsAny(text, ["雨", "异地", "旅行", "夜", "聚餐", "通勤"]) { score += 2 }
        if signal.kind == .lifeMark || signal.kind == .voice { score += 2 }
        return min(score, 6)
    }

    private static func imageryScore(for signal: LifeStorySignal, text: String) -> Int {
        var score = signal.profile == .defaultSoft ? 1 : 3
        if containsAny(text, ["雨", "路上", "回家", "夜里", "通勤", "聚餐", "蒸汽", "晚归"]) { score += 2 }
        if signal.kind == .scene { score += 1 }
        return min(score, 6)
    }

    private static func emotionScore(
        for signal: LifeStorySignal,
        text: String,
        hasConcreteSceneSupport: Bool
    ) -> Int {
        var score = signal.kind == .emotion ? 3 : 1
        if containsAny(text, ["提神", "恢复", "见面", "想家", "赶路", "放松", "松口气"]) { score += 2 }
        if signal.kind == .emotion && hasConcreteSceneSupport { score += 1 }
        return min(score, 6)
    }

    private static func continuityScore(for signal: LifeStorySignal, text: String) -> Int {
        var score = 1
        if signal.kind == .rhythm || signal.kind == .category { score += 2 }
        if containsAny(text, ["这周", "最近", "总会", "常常", "连续"]) { score += 2 }
        return min(score, 5)
    }

    private static func shareSafetyScore(for signal: LifeStorySignal, text: String) -> Int {
        var score = 4
        if containsAny(text, ["医院", "药", "补牙", "门诊", "检查"]) { score -= 2 }
        if containsAny(text, ["借", "还款", "欠", "报销"]) { score -= 2 }
        if signal.kind == .voice && text.count > 14 { score -= 1 }
        return max(1, score)
    }

    private static func leadBiasScore(
        for signal: LifeStorySignal,
        text: String,
        hasConcreteSceneSupport: Bool
    ) -> Int {
        var score: Int
        switch signal.kind {
        case .lifeMark:
            score = 5
        case .scene:
            score = 4
        case .emotion:
            score = hasConcreteSceneSupport || signal.profile != .defaultSoft ? 3 : 1
        case .voice:
            score = 2
        case .activity, .scent:
            score = 1
        case .rhythm:
            score = -2
        case .category:
            score = -3
        }
        if containsAny(text, ["连续"]) && signal.kind != .lifeMark {
            score -= 3
        }
        return score
    }

    private static func shouldForceLifeMarkLead(_ choice: SignalSelectionChoice) -> Bool {
        let signal = choice.signal
        guard signal.kind == .lifeMark || signal.kind == .voice else { return false }
        guard !isMechanicalContinuity(signal.rawText) else { return false }
        return containsAny(signal.rawText, ["第一次", "重新", "恢复", "终于", "开始", "久违"])
            && choice.scorecard.shareSafety >= 2
    }

    private static func shouldForceSceneLead(_ choice: SignalSelectionChoice) -> Bool {
        let signal = choice.signal
        guard signal.kind == .scene else { return false }
        guard !isMechanicalContinuity(signal.rawText) else { return false }
        return isConcreteScene(signal.rawText) && choice.scorecard.shareSafety >= 2
    }

    private static func preferredLifeMarkLead(_ choice: SignalSelectionChoice) -> Bool {
        choice.signal.kind == .lifeMark &&
            !isMechanicalContinuity(choice.signal.rawText) &&
            choice.scorecard.shareSafety >= 2
    }

    private static func preferredEmotionLead(_ choice: SignalSelectionChoice) -> Bool {
        let signal = choice.signal
        guard signal.kind == .emotion else { return false }
        guard !isGenericEmotion(signal.rawText) else { return false }
        return (signal.profile != .defaultSoft || choice.scorecard.imagery >= 4) &&
            choice.scorecard.shareSafety >= 2
    }

    private static func preferredVoiceLead(_ choice: SignalSelectionChoice) -> Bool {
        let signal = choice.signal
        guard signal.kind == .voice else { return false }
        guard !isMechanicalContinuity(signal.rawText) else { return false }
        return choice.scorecard.shareSafety >= 3
    }

    private static func canLeadNarrative(_ choice: SignalSelectionChoice) -> Bool {
        switch choice.signal.kind {
        case .rhythm, .category:
            return false
        case .emotion:
            return !isGenericEmotion(choice.signal.rawText)
        default:
            return !isMechanicalContinuity(choice.signal.rawText)
        }
    }

    private static func isConcreteScene(_ text: String) -> Bool {
        containsAny(text, ["雨", "通勤", "路上", "回家", "夜", "晚归", "异地", "旅行", "聚餐", "朋友", "见面"])
    }

    private static func isGenericEmotion(_ text: String) -> Bool {
        containsAny(text, ["日常", "平静", "普通", "还行", "一般", "记录一下"])
    }

    private static func isMechanicalContinuity(_ text: String) -> Bool {
        containsAny(text, ["连续", "占比", "消费", "支出", "记录", "有记录"])
    }

    private static func outwardShareHeadline(
        primary: LifeStorySignal,
        supports: [LifeStorySignal],
        fallback: String
    ) -> String {
        let text = narrativeCore(primary.rawText)
        switch primary.kind {
        case .lifeMark:
            if isMilestonePhrase(text) {
                return weeklyLead(text)
            }
            if let scene = supports.first(where: { $0.kind == .scene })?.rawText {
                return weeklyLead("也记下了\(sceneLead(scene))")
            }
            return weeklyLead(humanizedMoment(text))
        case .scene:
            if isConcreteScene(text) {
                return weeklyLead("也记下了\(sceneLead(text))")
            }
            return weeklyLead(sceneLead(text))
        case .emotion:
            if let scene = supports.first(where: { $0.kind == .scene })?.rawText {
                return weeklyLead("\(sceneLead(scene))，也记录了「\(softEmotion(text))」")
            }
            return weeklyLead("也记录了「\(softEmotion(text))」")
        case .voice:
            if isShortShareableQuote(text) {
                return weeklyLead("记录了「\(text)」")
            }
            return "这周，记下了一句话"
        case .activity:
            return weeklyLead(humanizedMoment(text))
        case .rhythm, .category, .scent:
            if let scene = supports.first(where: { $0.kind == .scene })?.rawText {
                return weeklyLead("也记下了\(sceneLead(scene))")
            }
            return softFallbackHeadline(fallback)
        }
    }

    private static func outwardSharePictureLine(
        primary: LifeStorySignal,
        supports: [LifeStorySignal],
        fallback: String
    ) -> String? {
        let scene = supports.first(where: { $0.kind == .scene })?.rawText
        let emotion = supports.first(where: { $0.kind == .emotion })?.rawText
        let text = narrativeCore(primary.rawText)
        switch primary.kind {
        case .lifeMark:
            if let scene {
                return scenePictureTemplate(scene, emotion: emotion, memory: text)
            }
            return weeklyPictureLine(text)
        case .scene:
            return scenePictureTemplate(text, emotion: emotion, memory: nil)
        case .emotion:
            if let scene {
                return scenePictureTemplate(scene, emotion: text, memory: nil)
            }
            return "这周也记下了「\(softEmotion(text))」。"
        case .voice:
            if let scene {
                return scenePictureTemplate(scene, emotion: emotion, memory: isShortShareableQuote(text) ? text : nil)
            }
            if isShortShareableQuote(text) {
                return "这周也记录了「\(text)」这句话。"
            }
            return clean(fallback)
        case .activity, .rhythm, .category, .scent:
            return scene.map { scenePictureTemplate($0, emotion: emotion, memory: nil) } ?? softFallbackPictureLine(fallback)
        }
    }

    private static func scenePictureTemplate(_ scene: String, emotion: String?, memory: String?) -> String {
        let cleanedScene = sceneLead(scene)
        if containsAny(cleanedScene, ["雨"]) {
            if let emotion {
                return "那天路上有雨，也记录了「\(softEmotion(emotion))」。"
            }
            if let memory, isMilestonePhrase(memory) {
                return "那天路上有雨，也记录了\(memory)。"
            }
            return "那天路上有雨，这一程也在这周的记录里。"
        }
        if containsAny(cleanedScene, ["回家", "下班", "夜", "晚归"]) {
            if let emotion {
                return "\(cleanedScene)，也记录了「\(softEmotion(emotion))」。"
            }
            return "\(cleanedScene)，也在这周的记录里。"
        }
        if containsAny(cleanedScene, ["聚餐", "朋友", "见面"]) {
            return "\(cleanedScene)，这周确实有过这样一顿或一次相聚。"
        }
        if let emotion {
            return "\(cleanedScene)，也记录了「\(softEmotion(emotion))」。"
        }
        if let memory, isMilestonePhrase(memory) {
            return "\(cleanedScene)，也记录了\(memory)。"
        }
        return "\(cleanedScene)，也在这周的记录里。"
    }

    private static func normalizedLeadText(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "被放进这一段里，", with: "")
            .replacingOccurrences(of: "这条线露了出来，", with: "")
            .replacingOccurrences(of: "这周也写下了「", with: "")
            .replacingOccurrences(of: "」", with: "")
    }

    private static func narrativeCore(_ raw: String) -> String {
        normalizedLeadText(raw)
            .replacingOccurrences(of: "这一周", with: "这周")
            .replacingOccurrences(of: "记进账本", with: "记下来")
            .replacingOccurrences(of: "记进了账本", with: "记了下来")
            .replacingOccurrences(of: "放进账本", with: "记下来")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func compactSentence(_ raw: String) -> String {
        let cleaned = narrativeCore(raw)
            .replacingOccurrences(of: "这一段", with: "这周")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count <= 24 { return cleaned }
        return String(cleaned.prefix(24))
    }

    private static func weeklyLead(_ body: String) -> String {
        let cleaned = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "这周，有几笔记录在这里" }
        if containsAny(cleaned, ["这周", "这一周", "本周"]) {
            return cleaned
        }
        return "这周，\(cleaned)"
    }

    private static func isMilestonePhrase(_ text: String) -> Bool {
        containsAny(text, ["第一次", "重新", "恢复", "终于", "开始", "久违"])
    }

    private static func shareTitleRole(for signal: LifeStorySignal?) -> ShareCopyRole {
        guard let signal else { return .softFallback }
        switch signal.kind {
        case .lifeMark:
            return .lifeMark
        case .scene:
            return .scene
        case .emotion:
            return isGenericEmotion(signal.rawText) ? .softFallback : .emotion
        case .voice:
            return isShortShareableQuote(narrativeCore(signal.rawText)) ? .voice : .softFallback
        case .activity, .rhythm, .category, .scent:
            return .softFallback
        }
    }

    private static func sharePictureRole(for signal: LifeStorySignal?, supports: [LifeStorySignal]) -> ShareCopyRole {
        if supports.contains(where: { $0.kind == .scene }) {
            return .scene
        }
        guard let signal else { return .softFallback }
        switch signal.kind {
        case .lifeMark:
            return .lifeMark
        case .scene:
            return .scene
        case .emotion:
            return .emotion
        case .voice:
            return isShortShareableQuote(narrativeCore(signal.rawText)) ? .voice : .softFallback
        case .activity, .rhythm, .category, .scent:
            return .softFallback
        }
    }

    private static func isShortShareableQuote(_ text: String) -> Bool {
        !text.isEmpty && text.count <= 12 && !isMechanicalContinuity(text)
    }

    private static func softEmotion(_ text: String) -> String {
        narrativeCore(text)
            .replacingOccurrences(of: "情绪", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "「」 "))
    }

    private static func humanizedMoment(_ text: String) -> String {
        let cleaned = compactSentence(text)
        if containsAny(cleaned, ["提神", "放松", "松口气", "恢复"]) {
            return "也记录了「\(softEmotion(cleaned))」"
        }
        if containsAny(cleaned, ["早餐", "咖啡", "奶茶", "晚饭"]) {
            return "\(cleaned)，这周也有这一笔"
        }
        return "\(cleaned)，这周也有这一笔"
    }

    private static func sceneLead(_ scene: String) -> String {
        let cleaned = compactSentence(scene)
        if containsAny(cleaned, ["雨", "通勤"]) { return "那次雨天通勤" }
        if containsAny(cleaned, ["雨"]) { return "那场雨里的路上" }
        if containsAny(cleaned, ["回家", "晚归", "夜", "下班"]) { return "那段晚归的路" }
        if containsAny(cleaned, ["聚餐", "朋友", "见面"]) { return "那次见面" }
        if containsAny(cleaned, ["异地", "旅行", "外地"]) { return "那次在外地时" }
        return cleaned
    }

    private static func weeklyPictureLine(_ text: String) -> String? {
        let cleaned = compactSentence(text)
        guard !cleaned.isEmpty else { return nil }
        if isMilestonePhrase(cleaned) {
            return "这周也记录了\(cleaned)。"
        }
        if containsAny(cleaned, ["提神", "放松", "松口气", "恢复"]) {
            return "那点「\(softEmotion(cleaned))」，这周也记下了。"
        }
        return "\(cleaned)，这周也有这一笔。"
    }

    private static func softFallbackHeadline(_ fallback: String) -> String {
        let cleaned = compactSentence(fallback)
        if cleaned.isEmpty || isMechanicalContinuity(cleaned) {
            return "这周的几笔记录，还在这里"
        }
        return weeklyLead(cleaned)
    }

    private static func softFallbackPictureLine(_ fallback: String) -> String? {
        let cleaned = compactSentence(fallback)
        if cleaned.isEmpty || isMechanicalContinuity(cleaned) {
            return "这周的几笔日常，也都在这里。"
        }
        return "这周也记录了\(cleaned)。"
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }
}

final class PlaybackMomentSelector {
    static let honestNoScentText = "记录还少"

    func select(
        from items: [HomeItem],
        periodKey: String,
        range: SummaryPlaybackRange,
        now: Date = Date(),
        echoAnchor: EchoAnchor? = nil
    ) -> PlaybackMomentSelection {
        let materials = playbackMaterials(in: items, periodKey: periodKey, now: now)
        let primary = preferredMaterial(from: materials, echoAnchor: echoAnchor)
        let scentWords = playbackScentWords(from: items, materials: materials)
        return PlaybackMomentSelection(materials: materials, primary: primary, scentWords: scentWords)
    }

    static func honestNoVoiceText(for range: SummaryPlaybackRange) -> String {
        switch range {
        case .week:
            return "这周的几笔记录"
        case .month:
            return "这个月的几笔记录"
        }
    }

    private func playbackMaterials(in items: [HomeItem], periodKey: String, now: Date) -> [PlaybackMoment] {
        items.compactMap { item -> PlaybackMoment? in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let defaultEmotion = HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
            let emotion = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
            var score = PlaybackMaterialScoring.stableScore(item: item, periodKey: periodKey, now: now)
            if HomeItem.isLateWorkCommute(item) {
                score += 30
            }

            if EchoAnchorService.shared.isEligibleLifeTraceTitle(title, item: item) {
                score += 70
                if item.userEditedTitle == true { score += 24 }
                if item.source == .manual { score += 8 }
                if emotion != defaultEmotion { score += 8 }
                score += lifeTraceWeightAdjustment(for: item, text: title)
                return PlaybackMoment(item: item, text: title, source: .title, score: score)
            }

            guard (2...18).contains(emotion.count),
                  emotion != defaultEmotion,
                  !EchoAnchorService.shared.isDirtyTraceTitle(emotion) else {
                return nil
            }
            score += 48
            if item.userEditedTitle == true { score += 8 }
            score += lifeTraceWeightAdjustment(for: item, text: emotion)
            return PlaybackMoment(item: item, text: emotion, source: .emotionTag, score: score)
        }
        .sorted {
            if $0.score == $1.score {
                return $0.item.createdAt > $1.item.createdAt
            }
            return $0.score > $1.score
        }
    }

    private func preferredMaterial(from materials: [PlaybackMoment], echoAnchor: EchoAnchor?) -> PlaybackMoment? {
        if let echoAnchor,
           let matched = materials.first(where: { $0.item.id == echoAnchor.itemId }) {
            return matched
        }
        return materials.first
    }

    private func playbackScentWords(from items: [HomeItem], materials: [PlaybackMoment]) -> [String] {
        var counts: [String: Int] = [:]
        var firstSeen: [String: Int] = [:]

        func add(_ raw: String) {
            let text = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "「」『』“”\"'，,。.!！?？、：:；;（）()[]【】"))
            guard (2...18).contains(text.count),
                  !EchoAnchorService.shared.isDirtyTraceTitle(text) else {
                return
            }
            if firstSeen[text] == nil { firstSeen[text] = firstSeen.count }
            counts[text, default: 0] += 1
        }

        materials.forEach { material in
            if !isLowSignalDrink(material.item, text: material.text) {
                add(material.text)
            }
        }
        for item in items {
            let defaultEmotion = HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
            let emotion = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
            if !emotion.isEmpty,
               emotion != defaultEmotion,
               !isLowSignalDrink(item, text: emotion) {
                add(emotion)
            }
            if EchoAnchorService.shared.isEligibleLifeTraceTitle(item.title, item: item),
               !isLowSignalDrink(item, text: item.title) {
                add(item.title)
            }
            add(LifeSceneSemanticService.displayTheme(for: LifeSceneSemanticService.classify(item)))
        }

        return counts
            .sorted {
                if $0.value == $1.value {
                    return (firstSeen[$0.key] ?? 0) < (firstSeen[$1.key] ?? 0)
                }
                return $0.value > $1.value
            }
            .prefix(5)
            .map(\.key)
    }

    private func lifeTraceWeightAdjustment(for item: HomeItem, text: String) -> Int {
        let normalized = "\(item.title) \(item.displayEmotionTag) \(text)"
        var adjustment = 0
        if containsAny(normalized, ["第一次", "第10次", "第 10 次", "连续", "恢复", "雨天", "下雨", "晚归", "宝宝", "奶粉", "尿不湿"]) {
            adjustment += 26
        }
        if isLowSignalDrink(item, text: normalized) {
            adjustment -= 46
        }
        if item.category == .dining, item.amount <= 20, !containsAny(normalized, ["第一次", "聚餐", "朋友", "宝宝"]) {
            adjustment -= 18
        }
        return adjustment
    }

    private func isLowSignalDrink(_ item: HomeItem, text: String) -> Bool {
        let normalized = "\(item.title) \(item.displayEmotionTag) \(text)"
        guard item.amount <= 25 else { return false }
        guard containsAny(normalized, ["咖啡", "拿铁", "美式", "奶茶", "茶饮", "饮品", "饮料", "喝的", "可乐", "雪碧", "汽水", "果汁", "柠檬茶", "水溶", "c100", "维c", "维C", "维他"]) else {
            return false
        }
        return !containsAny(normalized, ["第一次", "恢复", "加班", "晚归", "雨天", "下雨", "聚餐", "朋友", "宝宝"])
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

}

final class SummaryPlaybackQuotaStore {
    private enum Keys {
        static let playbackWeekKey = "playbackWeekKey"
        static let playbackWeekUsed = "playbackWeekUsed"
        static let playbackWeekUsedCount = "playbackWeekUsedCount"
        static let lifetimeMonthChapterRemaining = "lifetimeMonthChapterRemaining"
        static let lifetimeWeekPlaybackCompleted = "lifetimeWeekPlaybackCompleted"
        static let quotaSchemaVersion = "summaryPlaybackQuotaSchemaVersion"
        static let lastLoginQuotaSyncUserId = "summaryPlaybackLastLoginQuotaSyncUserId"
        static let lastCompletedWeekKey = "lastCompletedWeekPlaybackKey"
        static let lastCompletedMonthKey = "lastCompletedMonthPlaybackKey"
    }

    static let weeklyFreeLimit = 3
    static let lifetimeMonthFreeLimit = 10

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateQuotaIfNeeded()
    }

    func currentWeekKey(now: Date = Date()) -> String {
        let calendar = PlaybackService.isoCalendar
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return "\(comps.yearForWeekOfYear ?? 0)-W\(String(format: "%02d", comps.weekOfYear ?? 0))"
    }

    func weekRemaining(isMember: Bool, now: Date = Date()) -> Int {
        guard !isMember else { return Int.max }
        syncWeekIfNeeded(now: now)
        return max(0, Self.weeklyFreeLimit - defaults.integer(forKey: Keys.playbackWeekUsedCount))
    }

    func monthRemaining(isMember: Bool) -> Int {
        guard !isMember else { return Int.max }
        return max(0, defaults.integer(forKey: Keys.lifetimeMonthChapterRemaining))
    }

    func canPlay(_ range: SummaryPlaybackRange, isMember: Bool, now: Date = Date()) -> Bool {
        guard !isMember else { return true }
        switch range {
        case .week:
            return weekRemaining(isMember: false, now: now) > 0
        case .month:
            return monthRemaining(isMember: false) > 0
        }
    }

    func markCompleted(_ range: SummaryPlaybackRange, isMember: Bool, progress: Double, now: Date = Date()) {
        guard progress >= 0.8 else { return }
        if range == .week {
            defaults.set(true, forKey: Keys.lifetimeWeekPlaybackCompleted)
            defaults.set(currentWeekKey(now: now), forKey: Keys.lastCompletedWeekKey)
        } else {
            defaults.set(currentMonthKey(now: now), forKey: Keys.lastCompletedMonthKey)
        }
        guard !isMember else { return }
        switch range {
        case .week:
            syncWeekIfNeeded(now: now)
            let used = defaults.integer(forKey: Keys.playbackWeekUsedCount)
            defaults.set(min(Self.weeklyFreeLimit, used + 1), forKey: Keys.playbackWeekUsedCount)
            defaults.set(defaults.integer(forKey: Keys.playbackWeekUsedCount) >= Self.weeklyFreeLimit, forKey: Keys.playbackWeekUsed)
        case .month:
            let remaining = monthRemaining(isMember: false)
            if remaining > 0 {
                defaults.set(remaining - 1, forKey: Keys.lifetimeMonthChapterRemaining)
            }
        }
    }

    func hasCompletedWeekPlaybackEver() -> Bool {
        defaults.bool(forKey: Keys.lifetimeWeekPlaybackCompleted)
    }

    func hasCompletedCurrentWeekPlayback(now: Date = Date()) -> Bool {
        defaults.string(forKey: Keys.lastCompletedWeekKey) == currentWeekKey(now: now)
    }

    func hasCompletedCurrentMonthPlayback(now: Date = Date()) -> Bool {
        defaults.string(forKey: Keys.lastCompletedMonthKey) == currentMonthKey(now: now)
    }

    func currentMonthKey(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: now)
    }

    func syncLocalUsageAfterLogin(userId: String, now: Date = Date()) {
        migrateQuotaIfNeeded()
        syncWeekIfNeeded(now: now)
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            defaults.set(trimmed, forKey: Keys.lastLoginQuotaSyncUserId)
        }
    }

    private func syncWeekIfNeeded(now: Date) {
        let key = currentWeekKey(now: now)
        if defaults.string(forKey: Keys.playbackWeekKey) != key {
            defaults.set(key, forKey: Keys.playbackWeekKey)
            defaults.set(false, forKey: Keys.playbackWeekUsed)
            defaults.set(0, forKey: Keys.playbackWeekUsedCount)
        }
    }

    private func migrateQuotaIfNeeded() {
        let version = defaults.integer(forKey: Keys.quotaSchemaVersion)
        guard version < 2 else { return }

        if defaults.object(forKey: Keys.playbackWeekUsedCount) == nil {
            defaults.set(defaults.bool(forKey: Keys.playbackWeekUsed) ? 1 : 0, forKey: Keys.playbackWeekUsedCount)
        } else {
            let used = defaults.integer(forKey: Keys.playbackWeekUsedCount)
            defaults.set(min(max(used, 0), Self.weeklyFreeLimit), forKey: Keys.playbackWeekUsedCount)
        }

        if defaults.object(forKey: Keys.lifetimeMonthChapterRemaining) == nil {
            defaults.set(Self.lifetimeMonthFreeLimit, forKey: Keys.lifetimeMonthChapterRemaining)
        } else {
            let legacyRemaining = defaults.integer(forKey: Keys.lifetimeMonthChapterRemaining)
            let migratedRemaining = min(Self.lifetimeMonthFreeLimit, max(0, legacyRemaining) + 7)
            defaults.set(migratedRemaining, forKey: Keys.lifetimeMonthChapterRemaining)
        }

        defaults.set(2, forKey: Keys.quotaSchemaVersion)
    }
}
final class DailyFeatureQuotaStore {
    private enum Keys {
        static let ocrImportDayKey = "ocrImportDayKey"
        static let ocrImportUsedCount = "ocrImportUsedCount"
        static let todayPlaybackDayKey = "todayPlaybackDayKey"
        static let todayPlaybackUsedCount = "todayPlaybackUsedCount"
        static let todayPlaybackCompletedDayKey = "todayPlaybackCompletedDayKey"
        static let todayPlaybackCompletedSignature = "todayPlaybackCompletedSignature"
    }

    static let todayPlaybackFreeLimit = 3
    static let ocrDailyFreeLimit = 3

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func ocrRemaining(isMember: Bool, now: Date = Date()) -> Int {
        guard !isMember else { return Int.max }
        syncDayIfNeeded(dayKey: Keys.ocrImportDayKey, usedKey: Keys.ocrImportUsedCount, now: now)
        return max(0, DailyFeatureQuotaStore.ocrDailyFreeLimit - defaults.integer(forKey: Keys.ocrImportUsedCount))
    }

    func todayPlaybackRemaining(isMember: Bool, now: Date = Date()) -> Int {
        guard !isMember else { return Int.max }
        syncDayIfNeeded(dayKey: Keys.todayPlaybackDayKey, usedKey: Keys.todayPlaybackUsedCount, now: now)
        return max(0, Self.todayPlaybackFreeLimit - defaults.integer(forKey: Keys.todayPlaybackUsedCount))
    }

    func canUseOCR(isMember: Bool, now: Date = Date()) -> Bool {
        ocrRemaining(isMember: isMember, now: now) > 0
    }

    func canPlayTodayPlayback(isMember: Bool, now: Date = Date()) -> Bool {
        todayPlaybackRemaining(isMember: isMember, now: now) > 0
    }

    func markOCRImported(isMember: Bool, now: Date = Date()) {
        guard !isMember else { return }
        syncDayIfNeeded(dayKey: Keys.ocrImportDayKey, usedKey: Keys.ocrImportUsedCount, now: now)
        let used = defaults.integer(forKey: Keys.ocrImportUsedCount)
        defaults.set(min(DailyFeatureQuotaStore.ocrDailyFreeLimit, used + 1), forKey: Keys.ocrImportUsedCount)
    }

    func markTodayPlaybackStarted(isMember: Bool, now: Date = Date()) {
        guard !isMember else { return }
        syncDayIfNeeded(dayKey: Keys.todayPlaybackDayKey, usedKey: Keys.todayPlaybackUsedCount, now: now)
        let used = defaults.integer(forKey: Keys.todayPlaybackUsedCount)
        defaults.set(min(Self.todayPlaybackFreeLimit, used + 1), forKey: Keys.todayPlaybackUsedCount)
    }

    func hasUnplayedTodayItems(_ items: [HomeItem], now: Date = Date()) -> Bool {
        let todayItems = items.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: now) }
        guard !todayItems.isEmpty else { return false }
        let dayKey = Self.localDayKey(for: now)
        guard defaults.string(forKey: Keys.todayPlaybackCompletedDayKey) == dayKey else {
            return true
        }
        return defaults.string(forKey: Keys.todayPlaybackCompletedSignature) != Self.todayItemsSignature(todayItems)
    }

    func markTodayPlaybackCompleted(
        items: [HomeItem],
        progress: Double,
        now: Date = Date()
    ) {
        guard progress >= 0.8 else { return }
        let todayItems = items.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: now) }
        guard !todayItems.isEmpty else { return }
        defaults.set(Self.localDayKey(for: now), forKey: Keys.todayPlaybackCompletedDayKey)
        defaults.set(Self.todayItemsSignature(todayItems), forKey: Keys.todayPlaybackCompletedSignature)
    }

    private func syncDayIfNeeded(dayKey: String, usedKey: String, now: Date) {
        let key = Self.localDayKey(for: now)
        if defaults.string(forKey: dayKey) != key {
            defaults.set(key, forKey: dayKey)
            defaults.set(0, forKey: usedKey)
        }
    }

    private static func localDayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func todayItemsSignature(_ items: [HomeItem]) -> String {
        items
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
                return lhs.createdAt < rhs.createdAt
            }
            .map { "\($0.id.uuidString.lowercased()):\(Int($0.updatedAt.timeIntervalSince1970 * 1_000))" }
            .joined(separator: "|")
    }
}
