import Foundation

struct EchoAnchor: Equatable {
    let snippet: String
    let kind: EchoAnchorKind
    let itemId: UUID
}

enum EchoAnchorKind: Equatable {
    case title
    case emotion
}

final class EchoAnchorService {
    static let shared = EchoAnchorService()

    private let privacyDenylist = ["密码", "身份证", "银行卡", "验证码"]
    private let previewFallbackTitles: Set<String> = [
        "吃饭的一小笔",
        "路上的一小段",
        "给生活添一点",
        "日常的一点补给",
        "留给放松的一笔",
        "停下来的一晚",
        "身体的一笔",
        "家里补一点",
        "心意往来的一笔",
        "今天的一小笔",
        "这顿饭记下来了",
        "这段路记下来了",
        "这次购物记下来了",
        "这次日用补给",
        "这次放松安排",
        "这晚住宿记下来了",
        "这次健康支出",
        "这笔居家开销",
        "这次人情往来",
        "这笔记录已放好",
    ]

    private init() {}

    func isEligibleLifeTraceTitle(_ title: String, item: HomeItem) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (4...18).contains(trimmed.count) else { return false }
        guard trimmed != item.category.defaultRecordTitle else { return false }
        guard !previewFallbackTitles.contains(trimmed) else { return false }
        guard !isDirtyTraceTitle(trimmed) else { return false }
        guard !privacyDenylist.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) else { return false }
        guard !isBrandHardTitle(trimmed, merchantBrandId: item.merchantBrandId, userEditedTitle: item.userEditedTitle == true) else {
            return false
        }
        if item.userEditedTitle != true, RecordPrefillService.isHabitTitle(trimmed, category: item.category) {
            return false
        }
        return true
    }

    func isDirtyTraceTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if RecordPrefillService.isDirtyTraceTitle(trimmed) { return true }
        let noisyPatterns = [
            #"^\d{1,2}:\d{2}!?[A-Z0-9!]*$"#,
            #"^!?[!A-Z]*5G[A-Z]?\d{1,3}$"#,
            #"^-?\s*[¥￥]?\s*[0-9]+(?:\.[0-9]{1,2})?\s*$"#,
        ]
        return noisyPatterns.contains { trimmed.range(of: $0, options: .regularExpression) != nil }
    }

    func isBrandHardTitle(_ title: String, merchantBrandId: String?) -> Bool {
        isBrandHardTitle(title, merchantBrandId: merchantBrandId, userEditedTitle: false)
    }

    func pickEchoAnchor(items: [HomeItem], periodKey: String, now: Date = Date()) -> EchoAnchor? {
        let periodItems = items
            .filter { $0.amount > 0 && isItem($0, inPeriod: periodKey, now: now) }
            .sorted { $0.createdAt > $1.createdAt }
        guard periodItems.count >= 2 else { return nil }

        let amounts = periodItems.map(\.amount).sorted()
        let p25 = percentile(amounts, fraction: 0.25)
        let p75 = percentile(amounts, fraction: 0.75)
        let median = percentile(amounts, fraction: 0.5)
        let recentStart = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now

        let titleCandidates = periodItems.compactMap { item -> (item: HomeItem, score: Int)? in
            guard isEligibleLifeTraceTitle(item.title, item: item) else { return nil }
            let defaultEmotion = HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
            var score = stableHash("\(item.id.uuidString)|\(periodKey)") % 5
            if item.createdAt >= recentStart { score += 30 }
            if item.displayEmotionTag != defaultEmotion { score += 25 }
            if item.amount >= p25 && item.amount <= p75 || item.amount <= median * 2 { score += 15 }
            if (6...14).contains(item.title.trimmingCharacters(in: .whitespacesAndNewlines).count) { score += 10 }
            if item.merchantBrandId != nil, item.userEditedTitle == true { score += 5 }
            if item.userEditedTitle == true { score += 5 }
            if isLowSignalDrink(item, text: item.title) { score -= 45 }
            if isStrongLifeTrace(item, text: item.title) { score += 22 }
            return (item, score)
        }

        if let picked = titleCandidates.max(by: { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.item.createdAt < rhs.item.createdAt
            }
            return lhs.score < rhs.score
        }) {
            return EchoAnchor(
                snippet: picked.item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                kind: .title,
                itemId: picked.item.id
            )
        }

        let emotionCandidates = periodItems.filter { item in
            let tag = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (2...18).contains(tag.count) else { return false }
            guard tag != HomeItem.inferEmotionTag(category: item.category, amount: item.amount) else { return false }
            guard !isDirtyTraceTitle(tag) else { return false }
            guard !privacyDenylist.contains(where: { tag.localizedCaseInsensitiveContains($0) }) else { return false }
            return true
        }
        guard let pickedEmotion = emotionCandidates.max(by: { lhs, rhs in
            let left = stableHash("\(lhs.id.uuidString)|\(periodKey)|emotion")
            let right = stableHash("\(rhs.id.uuidString)|\(periodKey)|emotion")
            return left < right
        }) else {
            return nil
        }
        return EchoAnchor(
            snippet: pickedEmotion.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: .emotion,
            itemId: pickedEmotion.id
        )
    }

    func formatEchoAnchorSentence(_ anchor: EchoAnchor) -> String {
        let snippet = anchor.snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !snippet.isEmpty else { return "" }
        switch anchor.kind {
        case .title:
            if stableHash(anchor.itemId.uuidString) % 2 == 0 {
                return "有一笔留着「\(snippet)」。"
            }
            return "账本里有一笔：「\(snippet)」。"
        case .emotion:
            return "有一笔标着「\(snippet)」。"
        }
    }

    func periodKeyForWeek(now: Date = Date()) -> String {
        SummaryPlaybackQuotaStore().currentWeekKey(now: now)
    }

    func periodKeyForMonth(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: now)
    }

    private func isBrandHardTitle(_ title: String, merchantBrandId: String?, userEditedTitle: Bool) -> Bool {
        guard !userEditedTitle, let merchantBrandId else { return false }
        return MerchantBrandCatalog.isExactBrandAlias(title, for: merchantBrandId)
    }

    private func isItem(_ item: HomeItem, inPeriod periodKey: String, now: Date) -> Bool {
        if periodKey.contains("-W") {
            guard let interval = PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: now) else { return true }
            return item.createdAt >= interval.start && item.createdAt < interval.end
        }
        let monthKey = periodKeyForMonth(now: item.createdAt)
        return monthKey == periodKey
    }

    private func percentile(_ values: [Double], fraction: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let clamped = min(max(fraction, 0), 1)
        let index = Int((Double(values.count - 1) * clamped).rounded())
        return values[min(max(index, 0), values.count - 1)]
    }

    private func isLowSignalDrink(_ item: HomeItem, text: String) -> Bool {
        let normalized = "\(item.title) \(item.displayEmotionTag) \(text)"
        guard item.amount <= 25 else { return false }
        guard containsAny(normalized, ["咖啡", "拿铁", "美式", "奶茶", "茶饮", "饮品", "饮料", "喝的", "可乐", "雪碧", "汽水", "果汁", "柠檬茶", "水溶", "c100", "维c", "维C", "维他"]) else {
            return false
        }
        return !isStrongLifeTrace(item, text: normalized)
    }

    private func isStrongLifeTrace(_ item: HomeItem, text: String) -> Bool {
        let normalized = "\(item.title) \(item.displayEmotionTag) \(text)"
        return containsAny(normalized, ["第一次", "第10次", "第 10 次", "连续", "恢复", "加班", "晚归", "雨天", "下雨", "聚餐", "朋友", "宝宝", "奶粉", "尿不湿"])
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func stableHash(_ value: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(Int.max))
    }
}
