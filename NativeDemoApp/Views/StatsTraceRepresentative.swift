import Foundation

enum TraceRepresentative {
    static func items(from items: [HomeItem]) -> [HomeItem] {
        guard items.count > 3 else { return items }
        let ranked = rankedItems(from: items)

        var selected: [HomeItem] = []
        var selectedCategories = Set<String>()
        for candidate in ranked where selected.count < 3 {
            let categoryKey = candidate.element.category.rawValue
            guard !selectedCategories.contains(categoryKey) else { continue }
            selected.append(candidate.element)
            selectedCategories.insert(categoryKey)
        }
        for candidate in ranked where selected.count < 3 {
            guard !selected.contains(where: { $0.id == candidate.element.id }) else { continue }
            selected.append(candidate.element)
        }
        return selected.sorted { $0.createdAt > $1.createdAt }
    }

    static func items(
        from items: [HomeItem],
        maxItems: Int,
        maxPerCategory: Int
    ) -> [HomeItem] {
        guard maxItems > 0 else { return [] }
        let ranked = rankedItems(from: items)

        var selected: [HomeItem] = []
        var categoryCounts: [String: Int] = [:]
        for candidate in ranked where selected.count < maxItems {
            let categoryKey = candidate.element.category.rawValue
            let count = categoryCounts[categoryKey, default: 0]
            guard count < maxPerCategory else { continue }
            selected.append(candidate.element)
            categoryCounts[categoryKey] = count + 1
        }
        return selected.sorted { $0.createdAt > $1.createdAt }
    }

    private static func rankedItems(from items: [HomeItem]) -> [(offset: Int, element: HomeItem)] {
        Array(items.enumerated()).sorted { lhs, rhs in
            let leftScore = score(item: lhs.element, index: lhs.offset)
            let rightScore = score(item: rhs.element, index: rhs.offset)
            if leftScore == rightScore {
                return lhs.element.createdAt > rhs.element.createdAt
            }
            return leftScore > rightScore
        }
    }

    static func score(item: HomeItem, index: Int) -> Int {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultTitle = item.category.defaultRecordTitle
        let defaultEmotion = HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
        let emotion = item.displayEmotionTag
        var score = 0
        if !emotion.isEmpty && emotion != defaultEmotion { score += 40 }
        if item.userEditedTitle == true { score += 30 }
        if title != defaultTitle && (4...18).contains(title.count) { score += 20 }
        if case .manual = item.source { score += 6 }
        score += min(index, 6) * 2
        if title == defaultTitle { score -= 12 }
        return score
    }
}
