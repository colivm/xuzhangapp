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
        let resolvedEmotionTag = NarrativeCopyResolver.resolveEmotionTag(
            context: NarrativeCopyResolver.Context(
                brandId: emotionBrandId,
                category: category,
                amount: input.amount,
                date: input.date,
                seed: title,
                note: title
            )
        )
        let emotionTag = RecordSemanticLexicon.isTitle(resolvedEmotionTag, compatibleWith: category)
            ? resolvedEmotionTag
            : HomeItem.inferEmotionTag(category: category, amount: input.amount)

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
        RecordSemanticLexicon.semanticCategory(of: title, fallback: fallback)
    }
}
