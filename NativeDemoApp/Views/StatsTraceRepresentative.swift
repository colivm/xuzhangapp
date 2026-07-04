import Foundation

enum TraceRepresentative {
    private struct RankedTraceItem {
        let element: HomeItem
        let score: Int
        let sceneKey: String
        let titleKey: String
    }

    static func items(from items: [HomeItem]) -> [HomeItem] {
        guard items.count > 3 else { return items }
        let ranked = rankedItems(from: items)

        var selected: [HomeItem] = []
        var selectedCategories = Set<String>()
        var selectedScenes = Set<String>()
        for candidate in ranked where selected.count < 3 {
            let categoryKey = candidate.element.category.rawValue
            let sceneKey = candidate.sceneKey
            guard !selectedCategories.contains(categoryKey) else { continue }
            guard !selectedScenes.contains(sceneKey) else { continue }
            selected.append(candidate.element)
            selectedCategories.insert(categoryKey)
            selectedScenes.insert(sceneKey)
        }
        for candidate in ranked where selected.count < 3 {
            guard !selected.contains(where: { $0.id == candidate.element.id }) else { continue }
            let sceneKey = candidate.sceneKey
            if selectedScenes.contains(sceneKey), selected.count < min(2, items.count) { continue }
            selected.append(candidate.element)
            selectedScenes.insert(sceneKey)
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
        var sceneCounts: [String: Int] = [:]
        var titleKeys = Set<String>()
        for candidate in ranked where selected.count < maxItems {
            let categoryKey = candidate.element.category.rawValue
            let count = categoryCounts[categoryKey, default: 0]
            guard count < maxPerCategory else { continue }
            let sceneKey = candidate.sceneKey
            let titleKey = candidate.titleKey
            if sceneCounts[sceneKey, default: 0] >= max(1, maxPerCategory) { continue }
            if !titleKey.isEmpty, titleKeys.contains(titleKey), selected.count < maxItems - 1 { continue }
            selected.append(candidate.element)
            categoryCounts[categoryKey] = count + 1
            sceneCounts[sceneKey, default: 0] += 1
            if !titleKey.isEmpty { titleKeys.insert(titleKey) }
        }
        return selected.sorted { $0.createdAt > $1.createdAt }
    }

    private static func rankedItems(from items: [HomeItem]) -> [RankedTraceItem] {
        Array(items.enumerated())
            .map { pair in
                rankedItem(item: pair.element, offset: pair.offset)
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.element.createdAt > rhs.element.createdAt
                }
                return lhs.score > rhs.score
            }
    }

    private static func rankedItem(item: HomeItem, offset: Int) -> RankedTraceItem {
        let scene = LifeSceneSemanticService.classify(item)
        return RankedTraceItem(
            element: item,
            score: score(item: item, index: offset, scene: scene),
            sceneKey: sceneKey(for: scene),
            titleKey: normalizedTitleKey(for: item)
        )
    }

    static func score(item: HomeItem, index: Int) -> Int {
        score(item: item, index: index, scene: LifeSceneSemanticService.classify(item))
    }

    private static func score(item: HomeItem, index: Int, scene: LifeSceneSignal) -> Int {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultTitle = item.category.defaultRecordTitle
        let defaultEmotion = HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
        let emotion = item.displayEmotionTag
        var score = 0
        if !emotion.isEmpty && emotion != defaultEmotion { score += 26 }
        if item.userEditedTitle == true { score += 34 }
        if item.userEditedCategory == true { score += 10 }
        if title != defaultTitle && (4...22).contains(title.count) { score += 18 }
        if item.hasMemoryImages { score += 18 }
        if item.memoryContext?.weatherKind != nil { score += 8 }
        if item.memoryContext?.semanticPlace != nil { score += 8 }
        if scene.confidenceTier == .strong { score += 10 }
        if scene.kind == .general { score -= 6 }
        if case .manual = item.source { score += 6 }
        score += min(index, 6) * 2
        if title == defaultTitle { score -= 12 }
        if RecordSemanticLexicon.isSystemGeneratedTitle(title) { score -= 16 }
        if RecordPrefillService.isDirtyTraceTitle(title) { score -= 20 }
        return score
    }

    private static func sceneKey(for signal: LifeSceneSignal) -> String {
        return "\(signal.kind.rawValue)|\(signal.category.rawValue)"
    }

    private static func normalizedTitleKey(for item: HomeItem) -> String {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty,
              title != item.category.defaultRecordTitle,
              !RecordSemanticLexicon.isSystemGeneratedTitle(title),
              !RecordPrefillService.isDirtyTraceTitle(title) else {
            return ""
        }
        return title.lowercased()
    }
}
