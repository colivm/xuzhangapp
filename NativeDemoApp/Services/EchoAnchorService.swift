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
        "照顾自己的一笔",
        "把家安顿一下",
        "心意往来的一笔",
        "今天的一小笔",
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
            if item.emotionTag != defaultEmotion { score += 25 }
            if item.amount >= p25 && item.amount <= p75 || item.amount <= median * 2 { score += 15 }
            if (6...14).contains(item.title.trimmingCharacters(in: .whitespacesAndNewlines).count) { score += 10 }
            if item.merchantBrandId != nil, item.userEditedTitle == true { score += 5 }
            if item.userEditedTitle == true { score += 5 }
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
            let tag = item.emotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
            return !tag.isEmpty && tag != HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
        }
        guard let pickedEmotion = emotionCandidates.max(by: { lhs, rhs in
            let left = stableHash("\(lhs.id.uuidString)|\(periodKey)|emotion")
            let right = stableHash("\(rhs.id.uuidString)|\(periodKey)|emotion")
            return left < right
        }) else {
            return nil
        }
        return EchoAnchor(
            snippet: pickedEmotion.emotionTag.trimmingCharacters(in: .whitespacesAndNewlines),
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
                return "有一笔你写下「\(snippet)」，像是那天给自己留的一点照顾。"
            }
            return "「\(snippet)」—— 有一笔是这样留在账本里的。"
        case .emotion:
            return "有一次你标记过「\(snippet)」，像一段很小的生活注脚。"
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

    private func stableHash(_ value: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(Int.max))
    }
}
