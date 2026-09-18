import Foundation

/// Shared by new records and both editors. Only committed user events advance
/// this state; generated text, loading a record and asynchronous hints do not.
struct RecordExplicitIntentState: Equatable {
    enum CategorySource: Equatable { case automatic, userSelection, handwritten }
    private(set) var category: HomeItem.Category
    private(set) var categorySource: CategorySource
    private(set) var revision: UInt64 = 0
    private(set) var categorySelectionRevision: UInt64?
    private(set) var handwrittenRevision: UInt64?

    init(category: HomeItem.Category, userSelectedCategory: Bool = false) {
        self.category = category
        categorySource = userSelectedCategory ? .userSelection : .automatic
    }

    var categoryWasSelectedByUser: Bool { categorySource == .userSelection }
    var preventsAutomaticCategoryChanges: Bool { categorySource != .automatic }

    mutating func selectCategory(_ category: HomeItem.Category) {
        revision &+= 1
        categorySelectionRevision = revision
        self.category = category
        categorySource = .userSelection
    }

    @discardableResult
    mutating func writeNote(_ text: String) -> HomeItem.Category? {
        revision &+= 1
        handwrittenRevision = revision
        guard let category = RecordExplicitIntentPolicy.category(for: text) else { return nil }
        self.category = category
        categorySource = .handwritten
        return category
    }

    mutating func adoptAutomaticCategory(_ category: HomeItem.Category) {
        guard !preventsAutomaticCategoryChanges else { return }
        self.category = category
    }
}

enum RecordExplicitIntentPolicy {
    /// Reuse existing factual vocabulary without changing the global classifier.
    /// Ambiguous categories cannot overturn a prior explicit decision. Contained
    /// words (咖啡 in 咖啡器具, 手机 in 手机话费) are not independent evidence.
    static func category(for text: String) -> HomeItem.Category? {
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !note.isEmpty, note != RecordSemanticLexicon.emptyNoteTitle else { return nil }
        let hits = RecordSemanticLexicon.keywordRules.flatMap { rule in
            rule.keywords.compactMap { keyword -> (word: String, category: HomeItem.Category, score: Double)? in
                let word = keyword.lowercased()
                guard word.count > 1, note.contains(word) else { return nil }
                return (word, rule.category, rule.score)
            }
        }
        let specific = hits.filter { hit in
            let longer = hits.filter { $0.word != hit.word && $0.word.contains(hit.word) }
            let residual = longer.reduce(note) { $0.replacingOccurrences(of: $1.word, with: "") }
            return residual.contains(hit.word)
        }
        var categories = Set(specific.filter { $0.score >= 3 }.map(\.category))
        if let strong = RecordSemanticLexicon.strongManualNoteCategory(of: note) {
            // Strong rules remain useful for phrases whose global score is lower.
            // A contained short word must not defeat a more specific phrase.
            if categories.isEmpty || categories.contains(strong) { categories.insert(strong) }
        }
        if SemanticBoundaryGuard.familyCareKind(in: note) != nil { categories.insert(.daily) }
        if let brand = MerchantBrandCatalog.matchBrand(in: note) {
            if !MerchantBrandCatalog.isConvenienceStoreBrand(brand) || categories.isEmpty {
                categories.insert(brand.category)
            }
        }
        guard categories.count == 1 else { return nil }
        return categories.first
    }

    static func hasCategoryConflict(note: String, category: HomeItem.Category) -> Bool {
        guard let meaning = self.category(for: note) else { return false }
        return meaning != category
    }
}

/// Monotonic request identity, not an amount comparison (1 -> 12 -> 1 is new input).
struct RecordAmountInputGate {
    static let delayNanoseconds: UInt64 = 180_000_000
    private(set) var revision: UInt64 = 0
    private(set) var pending: UInt64?

    mutating func begin() -> UInt64 {
        revision &+= 1
        pending = revision
        return revision
    }

    mutating func finish(_ request: UInt64) -> Bool {
        guard pending == request else { return false }
        pending = nil
        return true
    }

    mutating func cancel() {
        revision &+= 1
        pending = nil
    }
}

/// Single-entry, non-publishing memo: even nil results are reusable.
final class RecordDraftMemo<Key: Equatable, Value> {
    private var cached: (key: Key, value: Value)?

    func value(for key: Key, build: () -> Value) -> Value {
        if let cached, cached.key == key { return cached.value }
        let value = build()
        cached = (key, value)
        return value
    }
}

/// Cheap raw identity only; constructing it must not resolve semantics or save drafts.
struct RecordPreviewComputationKey: Equatable {
    var calendar: Calendar = .current
    var amountText: String
    var title: String
    var category: HomeItem.Category
    var categoryLocked: Bool
    var date: Date
    var generatedNote: RecordGeneratedNoteContext?
    var noteEditorExpanded: Bool
    var noteIntent: Bool
    var lineWasRotated: Bool
    var scenePackID: String?
    var scenePackCategory: HomeItem.Category?
    var noteAnchor: String?
    var prefillTitle: String?
    var prefillCategory: HomeItem.Category?
    var prefillEmotion: String?
    var prefillSource: String?
    var prefillConfidence: Double?
    var weatherEnabled: Bool
    var weather: WeatherSnapshot?
}

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
    var scenePackId: String? = nil
    var generatedNoteContext: RecordGeneratedNoteContext? = nil
    var categoryIsSettled: Bool = false
    var preserveConfirmedTitle: Bool = false
    var manualNoteAnchor: String? = nil
}

/// Ephemeral identity only: changing expression is not a category or scene-pack edit.
struct RecordEmotionSceneContext: Hashable {
    let title: String
    let category: HomeItem.Category
    let amount: Double
    let date: Date
    let merchantBrandID: String?
    let scenePackID: String?
    let semanticAnchor: String?
    let previewEmotionTag: String
    let automaticEmotionTag: String

    func matches(resolution: RecordDraftResolution, amount: Double, date: Date, scenePackID: String?) -> Bool {
        title == resolution.title && category == resolution.category
            && self.amount == amount && self.date == date
            && merchantBrandID == resolution.merchantBrandId && self.scenePackID == scenePackID
    }

    func item(emotionTag: String) -> HomeItem {
        HomeItem(
            title: title, amount: amount, category: category, createdAt: date,
            emotionTag: emotionTag, merchantBrandId: merchantBrandID, scenePackId: scenePackID
        )
    }
}

struct RecordEmotionSelection: Equatable {
    let context: RecordEmotionSceneContext
    let tag: String
}

enum RecordEmotionScenePolicy {
    /// A bounded scene-local scan, never the whole category's copy pool.
    static func candidates(for context: RecordEmotionSceneContext) -> [String] {
        guard context.amount > 0, !context.title.isEmpty,
              context.title != RecordSemanticLexicon.emptyNoteTitle else { return [] }
        let note = [context.title, context.semanticAnchor].compactMap { $0 }.joined(separator: " ")
        let seed = [context.title, context.semanticAnchor].compactMap { $0 }.joined(separator: "|")
        let allowedRules = Set(RecordSemanticLexicon.matchingEmotionRuleIDs(in: note + " " + context.previewEmotionTag))
        let automaticDisplayTag = context.item(emotionTag: context.automaticEmotionTag).displayEmotionTag
        var result: [String] = []
        var seen: Set<String> = []

        // Both sources pass the same gate, including the save-time revalidation.
        func appendIfCompatible(_ tag: String) {
            guard !tag.isEmpty, seen.insert(tag).inserted,
                  RecordSemanticLexicon.isTitle(tag, compatibleWith: context.category),
                  Set(RecordSemanticLexicon.matchingEmotionRuleIDs(in: tag)).isSubset(of: allowedRules),
                  context.item(emotionTag: tag).displayEmotionTag == tag,
                  legacyFactSignature(tag) == legacyFactSignature(automaticDisplayTag),
                  rewardFactSignature(title: context.title, tag: tag)
                    == rewardFactSignature(title: context.title, tag: automaticDisplayTag) else { return }
            result.append(tag)
        }

        for index in 0..<24 {
            if Task.isCancelled { return [] }
            let tag = index == 0 ? context.previewEmotionTag : NarrativeCopyResolver.resolveEmotionTag(
                context: NarrativeCopyResolver.Context(
                    brandId: context.merchantBrandID, category: context.category,
                    amount: context.amount, date: context.date,
                    seed: seed + "|emotionChoice:\(index)", note: note, scenePackId: context.scenePackID
                )
            )
            appendIfCompatible(tag)
            if result.count == 6 { break }
        }
        // Preserve existing working pools/order. Only a collapsed pool needs the
        // local semantic source; never change the automatic default or draft facts.
        if result.count < 2 {
            for tag in RecordEmotionCandidateSource.alternatives(for: context) {
                if Task.isCancelled { return [] }
                appendIfCompatible(tag)
                if result.count == 6 { break }
            }
        }
        return result
    }

    static func next(after current: String, candidates: [String]) -> String? {
        guard candidates.count > 1 else { return nil }
        guard let index = candidates.firstIndex(of: current) else { return candidates.first }
        return candidates[(index + 1) % candidates.count]
    }

    static func validatedTag(
        selection: RecordEmotionSelection?, resolution: RecordDraftResolution,
        amount: Double, date: Date, scenePackID: String?, automaticEmotionTag: String
    ) -> String? {
        guard let selection,
              selection.context.matches(resolution: resolution, amount: amount, date: date, scenePackID: scenePackID),
              selection.context.automaticEmotionTag == automaticEmotionTag,
              candidates(for: selection.context).contains(selection.tag) else { return nil }
        return selection.tag
    }

    /// These legacy expressions are still factual inputs in LifeMarkService.
    /// A label choice must neither add nor remove weather, commute, or away evidence.
    private static func legacyFactSignature(_ tag: String) -> [Bool] {
        let groups = [
            ["热天路上", "高温通勤", "热天通勤"],
            ["冷天出门", "低温通勤", "冷天通勤"],
            ["雨天通勤", "下雨通勤"],
            ["雪天通勤", "下雪通勤"],
            ["通勤路上", "雨天通勤", "雪天通勤", "冷天出门", "热天路上"],
            ["外地记录", "异地记录", "外地停留", "异地停留"],
            ["雨天通勤", "下雨通勤", "雨天路上"]
        ]
        return groups.map { words in words.contains { tag.contains($0) } }
    }

    /// Reward eligibility also reads displayEmotionTag, including previous-record
    /// keyword hits. Preserve each hit, not just the currently winning reward group.
    private static func rewardFactSignature(title: String, tag: String) -> [Bool] {
        let text = title + " " + tag
        let keywords = SemanticBoundaryGuard.babyStrongKeywords + SemanticBoundaryGuard.petStrongKeywords + [
            "露营", "帐篷", "天幕", "睡袋", "渔具", "鱼竿", "鱼线", "鱼饵", "骑行", "摄影", "相机", "镜头", "乐器", "吉他", "键盘",
            "健身", "健身训练", "跑步", "瑜伽", "游泳", "私教", "健身卡", "健身房", "理疗", "康复", "护具", "运动鞋", "运动服", "运动装备",
            "酒店", "民宿", "住宿", "机票", "高铁", "火车", "机场", "景区", "景点", "门票", "旅行", "旅游", "露营地"
        ]
        return [
            SemanticBoundaryGuard.matchesBabySupply(text),
            SemanticBoundaryGuard.matchesPetSupply(text),
            SemanticBoundaryGuard.matchesLongDistanceTransit(text)
        ] + keywords.map { text.localizedCaseInsensitiveContains($0) }
    }
}

/// Record-only fallback for known scene facts, not a classifier or auto-copy rule.
/// A source is selected once from semantics, never from complete note templates.
enum RecordEmotionCandidateSource {
    private enum Scene: Equatable {
        case breakfast, lunch, dinner
        case coffee, drink
        case food(String)

        var alternatives: [String] {
            switch self {
            case .breakfast: return ["早餐这顿记下", "这顿早饭记下", "早餐留一笔"]
            case .lunch: return ["午餐这顿记下", "这顿午饭记下", "午餐留一笔"]
            case .dinner: return ["晚餐这顿记下", "这顿晚饭记下", "晚餐留一笔"]
            case .coffee: return ["咖啡这杯记下", "这杯咖啡记一笔", "买杯咖啡记下"]
            case .drink: return ["这次饮品记下", "喝的这一笔", "饮品留一笔"]
            case .food(let subject): return ["\(subject)这份记下", "这份\(subject)记一笔", "\(subject)这一笔"]
            }
        }

        var canonicalMealTag: String? {
            switch self {
            case .breakfast: return "早餐先记下"
            case .lunch: return "中午一顿饭"
            case .dinner: return "晚饭时间坐一会儿"
            default: return nil
            }
        }
    }

    static func alternatives(for context: RecordEmotionSceneContext) -> [String] {
        if context.category == .transport {
            return lateCommuteAlternatives(for: context)
        }
        guard context.category == .dining,
              !context.previewEmotionTag.isEmpty,
              context.previewEmotionTag == context.automaticEmotionTag,
              let scene = scene(in: context.title) else { return [] }
        let anchor = context.semanticAnchor?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard anchor.isEmpty || self.scene(in: anchor) == scene else { return [] }
        if let canonical = scene.canonicalMealTag {
            guard context.merchantBrandID == nil,
                  MerchantBrandCatalog.matchBrand(in: context.title) == nil,
                  context.previewEmotionTag == canonical else { return [] }
        } else if scene == .coffee || scene == .drink {
            // A wrong automatic meal label is a separate default-copy issue;
            // don't mix drink choices into it and hide that mismatch.
            guard !RecordSemanticLexicon.matchingEmotionRuleIDs(in: context.previewEmotionTag).contains("meal") else { return [] }
        }
        return scene.alternatives
    }

    private static func lateCommuteAlternatives(for context: RecordEmotionSceneContext) -> [String] {
        let canonical = "晚上这段通勤"
        guard context.merchantBrandID == nil,
              context.scenePackID == nil || context.scenePackID == "commute",
              context.previewEmotionTag == canonical,
              context.automaticEmotionTag == canonical else { return [] }

        // Reuse the existing time/commute resolver, but only supplement a plain,
        // explicit commute. Do not invent work, weather, or a transport method.
        func isSameScene(_ text: String) -> Bool {
            let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.contains("通勤"),
                  MerchantBrandCatalog.matchBrand(in: text) == nil,
                  RecordSemanticLexicon.matchingEmotionRuleIDs(in: text).isSubset(of: ["transport"]),
                  !["上班", "下班", "早班", "到岗", "早高峰", "晚高峰", "加班", "工作", "公司", "单位", "工位",
                    "雨天", "下雨", "雨中", "雪天", "下雪", "雪中", "高温", "低温", "冷天", "热天"]
                    .contains(where: { text.contains($0) }) else { return false }
            return HomeItem.refinedEmotionTag(
                title: text, category: context.category, amount: context.amount, date: context.date
            ) == canonical
        }

        let anchor = context.semanticAnchor?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard isSameScene(context.title), anchor.isEmpty || isSameScene(anchor) else { return [] }
        return ["晚间这段通勤", "这趟晚间通勤记下", "晚上的通勤记一笔"]
    }

    private static func scene(in text: String) -> Scene? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rules = RecordSemanticLexicon.matchingEmotionRuleIDs(in: text)
        // Strong contextual narratives stay with the existing resolver. No new
        // weather/work/route facts may be inferred from the clock or the brand.
        guard rules.isSubset(of: ["meal", "drink", "convenience"]),
              !["雨天", "下雨", "雨中", "雪天", "下雪", "雪中", "加班", "上班", "下班", "晚归", "赶路", "赶车", "机场", "高铁", "火车"]
                .contains(where: { text.contains($0) }) else { return nil }
        let meals: [(Scene, [String])] = [
            (.breakfast, ["早餐", "早饭"]), (.lunch, ["午餐", "午饭", "中午"]),
            (.dinner, ["晚餐", "晚饭"])
        ]
        let explicitMeals = meals.filter { _, cues in cues.contains { text.contains($0) } }
        guard explicitMeals.count <= 1,
              !["夜宵", "宵夜", "深夜", "凌晨", "夜市", "夜摊"].contains(where: { text.contains($0) }) else { return nil }

        if let kind = DiningCopyEvidencePolicy.specificKind(in: text) {
            switch kind {
            case .coffee: return .coffee
            case .drink: return .drink
            case .riceBall: return .food("饭团")
            case .bento: return .food("便当")
            case .oden: return .food("关东煮")
            case .teaEgg: return .food("茶叶蛋")
            case .sandwich: return .food("三明治")
            case .bun: return text.contains("包子") ? .food("包子") : nil
            // This existing kind includes rice noodles and malatang as well.
            case .noodles: return .food("餐食")
            // These have their own contextual food rules or mixed-food semantics.
            case .wonton, .potsticker, .panFriedBun, .dumpling, .riceMeal, .hotpot, .snack: return nil
            }
        }
        if rules.contains("drink") { return .drink }
        return explicitMeals.first?.0
    }
}

enum RecordDraftResolutionService {
    static func resolve(_ input: RecordDraftResolutionInput) -> RecordDraftResolution {
        var trace: [String] = []
        let initialTitle = input.rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let keepsGeneratedCategory = input.generatedNoteContext?.matches(
            title: initialTitle,
            category: input.fallbackCategory
        ) == true
        let brand = MerchantBrandCatalog.definition(for: input.merchantBrandId)
            ?? MerchantBrandCatalog.matchBrand(in: initialTitle)
        // Keep explicit meaning even when it already matches the selected
        // category; otherwise a convenience-store brand can override it again.
        let semanticCategory = RecordSemanticLexicon.semanticCategory(of: initialTitle)
        let semanticOverridesConvenienceBrand = brand.map { brand in
            MerchantBrandCatalog.isConvenienceStoreBrand(brand)
                && semanticCategory != nil
                && semanticCategory != brand.category
        } ?? false
        let suppressBrand = input.categoryLockedByUser || semanticOverridesConvenienceBrand ||
            ((keepsGeneratedCategory || input.categoryIsSettled) && brand?.category != input.fallbackCategory)
        let brandId = suppressBrand ? nil : brand?.id

        let category: HomeItem.Category
        if input.categoryLockedByUser {
            category = input.fallbackCategory
            trace.append("category:userLocked")
        } else if input.categoryIsSettled {
            category = input.fallbackCategory
            trace.append("category:explicitIntent")
        } else if keepsGeneratedCategory {
            category = input.fallbackCategory
            trace.append("category:generatedDraft")
        } else if semanticOverridesConvenienceBrand, let semanticCategory {
            category = semanticCategory
            trace.append("category:semantic")
        } else if let brand {
            category = brand.category
            trace.append("category:brand")
        } else if let semanticCategory {
            category = semanticCategory
            trace.append("category:semantic")
        } else {
            category = input.fallbackCategory
            trace.append("category:fallback")
        }

        let baseTitle = initialTitle.isEmpty ? category.defaultRecordTitle : initialTitle
        let resolvedTitle = NarrativeCopyResolver.resolveTitle(brandId: brandId, fallback: baseTitle)
        let shouldPreserveBrandTitle = brand.map { brand in
            MerchantBrandCatalog.isExactBrandAlias(resolvedTitle, for: brand.id)
                || MerchantBrandCatalog.matchBrand(in: resolvedTitle)?.id == brand.id
        } ?? false
        let shouldKeepUserTitle = input.userEditedTitle
            && !initialTitle.isEmpty
            && initialTitle != RecordSemanticLexicon.emptyNoteTitle
        let title = shouldKeepUserTitle || input.preserveConfirmedTitle || (keepsGeneratedCategory && !input.categoryLockedByUser)
            ? initialTitle
            : shouldPreserveBrandTitle
                ? resolvedTitle
                : RecordSemanticLexicon.repairedTitle(
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
                note: title,
                scenePackId: input.scenePackId
            )
        )
        let hasManualConflict = input.manualNoteAnchor.map {
            RecordExplicitIntentPolicy.hasCategoryConflict(note: $0, category: category)
        } ?? false
        let emotionTag = hasManualConflict ? "" : (
            RecordSemanticLexicon.isTitle(resolvedEmotionTag, compatibleWith: category)
                ? resolvedEmotionTag
                : HomeItem.inferEmotionTag(category: category, amount: input.amount)
        )

        return RecordDraftResolution(
            category: category,
            title: title,
            emotionTag: emotionTag,
            merchantBrandId: brandId,
            source: input.source,
            trace: trace
        )
    }

}
