import Foundation

struct RecordDraftResolution {
    let category: HomeItem.Category
    let title: String
    let emotionTag: String
    let merchantBrandId: String?
    let source: String
    let trace: [String]
}

struct RecordDraftResolutionInput {
    let rawTitle: String
    let fallbackCategory: HomeItem.Category
    let amount: Double
    let date: Date
    let merchantBrandId: String?
    let categoryLockedByUser: Bool
    let userEditedTitle: Bool
    let source: String
}

enum RecordDraftResolutionService {
    static func resolve(_ input: RecordDraftResolutionInput) -> RecordDraftResolution {
        var trace: [String] = []
        let initialTitle = input.rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = MerchantBrandCatalog.definition(for: input.merchantBrandId)
            ?? MerchantBrandCatalog.matchBrand(in: initialTitle)
        let brandId = input.categoryLockedByUser ? nil : brand?.id

        let category: HomeItem.Category
        if input.categoryLockedByUser {
            category = input.fallbackCategory
            trace.append("category:userLocked")
        } else if let brand {
            category = brand.category
            trace.append("category:brand")
        } else if let semanticCategory = semanticCategory(from: initialTitle, fallback: input.fallbackCategory) {
            category = semanticCategory
            trace.append("category:semantic")
        } else {
            category = input.fallbackCategory
            trace.append("category:fallback")
        }

        let baseTitle = initialTitle.isEmpty ? category.defaultRecordTitle : initialTitle
        let resolvedTitle = NarrativeCopyResolver.resolveTitle(brandId: brandId, fallback: baseTitle)
        let title = RecordSemanticLexicon.repairedTitle(
            for: resolvedTitle,
            category: category,
            amount: input.amount,
            date: input.date,
            userEditedTitle: input.userEditedTitle
        )
        if title != resolvedTitle { trace.append("title:semanticRepair") }

        let emotionBrandId = MerchantBrandCatalog.definition(for: brandId)?.category == category ? brandId : nil
        let emotionTag = NarrativeCopyResolver.resolveEmotionTag(
            context: NarrativeCopyResolver.Context(
                brandId: emotionBrandId,
                category: category,
                amount: input.amount,
                date: input.date,
                seed: title,
                note: title
            )
        )

        return RecordDraftResolution(
            category: category,
            title: title,
            emotionTag: emotionTag,
            merchantBrandId: brand?.id,
            source: input.source,
            trace: trace
        )
    }

    private static func semanticCategory(
        from title: String,
        fallback: HomeItem.Category
    ) -> HomeItem.Category? {
        let matches = RecordSemanticLexicon.matchingCategories(in: title)
        guard !matches.isEmpty, !matches.contains(fallback) else { return nil }
        return matches.sorted { lhs, rhs in
            semanticPriority(lhs) < semanticPriority(rhs)
        }.first
    }

    private static func semanticPriority(_ category: HomeItem.Category) -> Int {
        switch category {
        case .transport: return 0
        case .dining: return 1
        case .shopping: return 2
        case .daily: return 3
        case .health: return 4
        case .home: return 5
        case .lodging: return 6
        case .social: return 7
        case .entertainment: return 8
        case .other: return 9
        }
    }
}
