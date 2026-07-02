import Foundation
import Combine

struct AICommandRecordDraft: Identifiable, Equatable {
    enum Status: Equatable {
        case ready
        case conflict(String)
    }

    let id: UUID
    var title: String
    var amount: Double
    var category: HomeItem.Category
    var date: Date
    var status: Status

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        category: HomeItem.Category,
        date: Date,
        status: Status = .ready
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.date = date
        self.status = status
    }
}

private struct ItemDerivedCache {
    var todayPositiveItems: [HomeItem] = []
    var recentThreeTodayItems: [HomeItem] = []
    var currentWeekItems: [HomeItem] = []
    var currentMonthItems: [HomeItem] = []
    var currentYearItems: [HomeItem] = []
}

@MainActor
final class HomeViewModel: ObservableObject {
    enum Period: String, CaseIterable, Identifiable {
        case week = "本周"
        case month = "本月"

        var id: String { rawValue }
    }

    struct FrequentRecordAmountSuggestion: Identifiable {
        let amount: Double
        let category: HomeItem.Category
        let count: Int
        let confidence: Double
        let latest: Date

        var id: String {
            "\(Int((amount * 100).rounded()))-\(category.rawValue)"
        }
    }

    @Published var inputTitle: String = ""
    @Published var inputAmount: String = ""
    @Published var selectedCategory: HomeItem.Category = .other
    @Published private(set) var categoryLockedByUser: Bool = false
    @Published var selectedDate: Date = .now
    @Published private(set) var selectedDateEditedByUser: Bool = false
    @Published var selectedPeriod: Period = .month
    @Published private(set) var ocrStatus: String = ""
    @Published private(set) var isGeneratingInsight: Bool = false
    @Published private(set) var isGeneratingMonthlyInsight: Bool = false
    @Published private(set) var insightErrorMessage: String?
    @Published private(set) var insights: [DailyInsight] = []
    @Published private(set) var items: [HomeItem] = [] {
        didSet {
            itemDerivedCacheNeedsRebuild = true
        }
    }
    @Published private(set) var syncStatusMessage: String?
    @Published private(set) var isSyncingCloudLedger: Bool = false
    @Published private(set) var memberNudgeCopy: MemberCtaCopy?
    @Published private(set) var activeMemberNudgeScene: MemberFlowScene?
    @Published private(set) var latestPlayback: PlaybackSnapshot?
    @Published private(set) var latestActionCard: ActionCardData?
    @Published private(set) var activeRouteGuidance: PlaybackRouteGuidance?
    @Published private(set) var recordPrefillResult: RecordPrefillResult?
    @Published private(set) var recordInputMessage: String?
    @Published var petMessage: String? = nil

    enum PlaybackRouteGuidance: String, Identifiable, Hashable {
        case firstRecordTodayPlayback
        case weekSliceReady
        case fiveRecordsNeverPlayed

        var id: String { rawValue }

        var title: String {
            switch self {
            case .firstRecordTodayPlayback:
                return "用十几秒叙一下今天"
            case .weekSliceReady:
                return "本周回放可播放"
            case .fiveRecordsNeverPlayed:
                return "可以讲这周的故事了"
            }
        }

        var message: String {
            switch self {
            case .firstRecordTodayPlayback:
                return "第一笔已经记好，听一遍今日回放。"
            case .weekSliceReady:
                return "本周已经有 3 笔以上记录，去看看花听一遍。"
            case .fiveRecordsNeverPlayed:
                return "已记 5 笔以上，还没完整听过周切片。"
            }
        }
    }

    struct ActionCardData: Codable, Equatable {
        var text: String
        var updatedAt: Date
        var scope: String // "weekly", "monthly", "none"
    }

    struct TodayStoryNarrative: Equatable {
        var title: String
        var subtitle: String
        var todayTotalText: String
        var weekTotalText: String
    }

    enum AIInsightSource: Equatable {
        case live
        case fallback
        case errorFallback

        var analyticsValue: String {
            switch self {
            case .live: return "live"
            case .fallback: return "local_fallback"
            case .errorFallback: return "error_fallback"
            }
        }
    }

    struct MonthlyInsightReport: Equatable {
        var summary: String
        var structure: String
        var advice: String
        var source: AIInsightSource
    }

    private let ocrService = OCRService()
    private let aiReportService = AIReportService()
    private let analyticsService = AnalyticsService()
    private let categoryRecommendService = CategoryRecommendService()
    private let recordPrefillService = RecordPrefillService()
    private let petCompanionService = PetCompanionService.shared
    private let nudgePolicyService = MemberNudgePolicyService()
    private let playbackService = PlaybackService()
    private let memberFlowService = MemberFlowService()
    private let routeQuotaStore = SummaryPlaybackQuotaStore()
    private let dailyQuotaStore = DailyFeatureQuotaStore()
    private static let routeGuidanceHandledDefaultsKey = "route_guidance_handled_v1"
    private var emittedRouteGuidanceKeys: Set<String> = []
    private var recordPrefillAmount: Double?
    private var lastAutoRecommendedCategory: HomeItem.Category?
    private var pendingCategoryCorrectionFrom: HomeItem.Category?
    private var itemDerivedCache = ItemDerivedCache()
    private var itemDerivedCacheDayKey: String?
    private var itemDerivedCacheNeedsRebuild = true

    init() {
        items = LocalStore.loadHomeItems().sorted { $0.createdAt > $1.createdAt }
        rebuildItemDerivedCache()
        insights = LocalStore.loadDailyInsights().sorted { $0.createdAt > $1.createdAt }
        if let data = UserDefaults.standard.data(forKey: "latest_action_card_v1"),
           let card = try? JSONDecoder().decode(ActionCardData.self, from: data) {
            // Expire cards based on scope
            let calendar = Calendar.current
            let daysSince = calendar.dateComponents([.day], from: card.updatedAt, to: Date()).day ?? 999
            let expired: Bool = {
                switch card.scope {
                case "weekly": return daysSince > 7
                case "monthly": return daysSince > 30
                default: return false
                }
            }()
            if !expired, !Self.isLowValueActionCardText(card.text) { latestActionCard = card }
        }
        analyticsService.track("app_open", props: ["items": String(items.count)])
        refreshTodayPlayback()
        refreshRouteGuidanceIfNeeded()
    }

    @discardableResult
    func addManualRecord(
        userEditedTitle: Bool = false,
        preserveEmptyTitle: Bool = false,
        categoryLockedForSave: Bool? = nil,
        scenePackId: String? = nil
    ) -> Bool {
        guard let amount = Double(inputAmount.replacingOccurrences(of: ",", with: "")), amount > 0 else { return false }
        let wasEmpty = items.isEmpty
        let shouldLockCategory = categoryLockedForSave ?? categoryLockedByUser
        let noteResult = UserContentRiskService.shared.validateManualNote(inputTitle, allowEmpty: true)
        guard noteResult.isAllowed else {
            recordInputMessage = noteResult.message
            return false
        }
        recordInputMessage = nil
        let trimmed = noteResult.value
        let titleWasIntentionallyBlank = preserveEmptyTitle && trimmed.isEmpty
        let prefillTitle = compatiblePrefillTitleForSave(category: selectedCategory)
        let baseTitle: String
        if titleWasIntentionallyBlank {
            baseTitle = RecordSemanticLexicon.emptyNoteTitle
        } else if trimmed.isEmpty, let prefillTitle {
            baseTitle = prefillTitle
        } else {
            baseTitle = trimmed.isEmpty ? selectedCategory.defaultRecordTitle : trimmed
        }
        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: baseTitle,
                fallbackCategory: selectedCategory,
                amount: amount,
                date: selectedDate,
                merchantBrandId: MerchantBrandCatalog.matchBrand(in: baseTitle)?.id,
                categoryLockedByUser: shouldLockCategory,
                userEditedTitle: userEditedTitle || titleWasIntentionallyBlank,
                source: "manual",
                scenePackId: scenePackId
            )
        )
        let emotionTag = memoryEnhancedEmotionTag(
            title: resolution.title,
            category: resolution.category,
            amount: amount,
            date: selectedDate,
            baseEmotionTag: resolution.emotionTag
        )
        let memoryContext = memoryContextForRecord(date: selectedDate)
        let newItem = HomeItem(
            title: resolution.title,
            amount: amount,
            category: resolution.category,
            source: .manual,
            createdAt: selectedDate,
            updatedAt: Date(),
            emotionTag: emotionTag,
            merchantBrandId: resolution.merchantBrandId,
            userEditedTitle: userEditedTitle && resolution.title == baseTitle ? true : nil,
            userEditedCategory: shouldLockCategory ? true : nil,
            categoryCorrectionFrom: shouldLockCategory ? pendingCategoryCorrectionFrom : nil,
            memoryContext: memoryContext,
            scenePackId: scenePackId
        )
        items.insert(newItem, at: 0)
        resetInput()
        persistItems()
        schedulePostManualRecordWork(for: newItem, wasEmpty: wasEmpty)
        return true
    }

    private func schedulePostManualRecordWork(for newItem: HomeItem, wasEmpty: Bool) {
        Task { @MainActor in
            await Task.yield()
            analyticsService.track(
                "record_saved",
                props: [
                    "category": newItem.category.rawValue,
                    "amount": String(format: "%.2f", newItem.amount),
                    "source": newItem.source.rawValue,
                ]
            )
            refreshTodayPlayback()
            if wasEmpty {
                emitRouteGuidance(.firstRecordTodayPlayback)
            } else {
                refreshRouteGuidanceIfNeeded()
            }
            enqueuePetMessage(for: newItem)
            Task { await syncUpsertToCloud(newItem) }
        }
    }

    private func compatiblePrefillTitleForSave(category: HomeItem.Category) -> String? {
        guard let result = recordPrefillResult,
              result.category == nil || result.category == category,
              let title = result.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty,
              RecordSemanticLexicon.canDisplayPrefillTitle(
                title,
                category: category,
                source: result.source
              ) else {
            return nil
        }
        return title
    }

    var ocrDraftItems: [HomeItem] {
        items
            .filter { $0.source == .ocr && $0.draftMeta != nil }
            .sorted {
                let left = $0.draftMeta?.importedAt ?? $0.createdAt
                let right = $1.draftMeta?.importedAt ?? $1.createdAt
                return left > right
            }
    }

    func makeDemoOCRDrafts() -> [OCRReceiptDraft] {
        [
            OCRReceiptDraft(
                title: "瑞幸咖啡",
                amount: 18.9,
                date: .now,
                category: .dining,
                confidence: 0.96,
                rawText: "微信支付\n商户全称 瑞幸咖啡\n金额 -¥18.90\n支付时间 \(Self.dayKey(for: .now)) 09:24:00",
                provider: .wechat
            ),
            OCRReceiptDraft(
                title: "便利店日用品",
                amount: 32.5,
                date: .now,
                category: .daily,
                confidence: 0.94,
                rawText: "支付宝\n商品说明 便利店日用品\n金额 ¥32.50\n付款时间 \(Self.dayKey(for: .now)) 19:06:00",
                provider: .alipay
            ),
        ]
    }

    func recognizeOCRDrafts(imageData: Data, isMember: Bool) async -> [OCRReceiptDraft] {
        guard dailyQuotaStore.canUseOCR(isMember: isMember) else {
            ocrStatus = ExperienceRuleCopy.ocrQuotaExhaustedMessage()
            return []
        }
        do {
            let rawDrafts = try await ocrService.recognizeReceipt(from: imageData)
            let drafts = rawDrafts.map { reviewedOCRDraft($0) }
            let count = drafts.count
            let total = drafts.reduce(0) { $0 + $1.amount }
            let message = "识别到 \(count) 条，合计 \(formatCurrency(total))。请确认后导入。"
            ocrStatus = message
            return drafts
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "这张图暂时没识别出来。可以再试一次，或手动记一笔。"
            ocrStatus = message
            return []
        }
    }

    func importOCRDrafts(_ drafts: [OCRReceiptDraft], isMember: Bool, sendToDrafts: Bool = true) -> Int {
        let validDrafts = drafts.filter { $0.amount > 0 }
        guard !validDrafts.isEmpty else {
            ocrStatus = "未选择可导入的账单。"
            return 0
        }
        guard dailyQuotaStore.canUseOCR(isMember: isMember) else {
            ocrStatus = ExperienceRuleCopy.ocrQuotaExhaustedMessage()
            return 0
        }

        let now = Date()
        let batchId = UUID().uuidString
        var memorySeedItems = items
        let importedItems = validDrafts.map { rawDraft in
            let draft = reviewedOCRDraft(rawDraft)
            let resolution = RecordDraftResolutionService.resolve(
                RecordDraftResolutionInput(
                    rawTitle: draft.title,
                    fallbackCategory: draft.category,
                    amount: draft.amount,
                    date: draft.date,
                    merchantBrandId: draft.merchantBrandId,
                    categoryLockedByUser: draft.userEditedCategory == true,
                    userEditedTitle: false,
                    source: "ocr"
                )
            )
            let emotionTag = memoryEnhancedEmotionTag(
                title: resolution.title,
                category: resolution.category,
                amount: draft.amount,
                date: draft.date,
                baseEmotionTag: resolution.emotionTag,
                existingItems: memorySeedItems
            )
            let memoryContext = memoryContextForRecord(date: draft.date)
            let item = HomeItem(
                title: resolution.title,
                amount: draft.amount,
                category: resolution.category,
                source: .ocr,
                createdAt: draft.date,
                updatedAt: now,
                emotionTag: emotionTag,
                merchantBrandId: resolution.merchantBrandId,
                draftMeta: sendToDrafts
                    ? HomeItem.DraftMeta(
                        batchId: batchId,
                        importedAt: now,
                        status: .pending
                    )
                    : nil,
                userEditedCategory: draft.userEditedCategory == true ? true : nil,
                categoryCorrectionFrom: draft.categoryCorrectionFrom,
                memoryContext: memoryContext
            )
            memorySeedItems.insert(item, at: 0)
            return item
        }
        items.insert(contentsOf: importedItems, at: 0)
        dailyQuotaStore.markOCRImported(isMember: isMember)
        persistItems()
        analyticsService.track(
            "ocr_records_imported",
            props: [
                "count": String(importedItems.count),
                "source": "ocr",
            ]
        )
        refreshTodayPlayback()
        refreshRouteGuidanceIfNeeded()
        updateOCRSuccessStatus(
            prefix: sendToDrafts ? "已导入 \(importedItems.count) 条，进入待整理" : "已直接导入 \(importedItems.count) 条",
            isMember: isMember
        )
        if let firstItem = importedItems.first {
            enqueuePetMessage(for: firstItem)
        }
        Task {
            for item in importedItems {
                await syncUpsertToCloud(item)
            }
        }
        return importedItems.count
    }

    @discardableResult
    func importAICommandDrafts(_ drafts: [AICommandRecordDraft]) -> Int {
        let validDrafts = drafts.filter {
            guard $0.amount > 0 else { return false }
            if case .conflict = $0.status { return false }
            return true
        }
        guard !validDrafts.isEmpty else { return 0 }

        let wasEmpty = items.isEmpty
        let now = Date()
        var memorySeedItems = items
        let importedItems = validDrafts.map { draft in
            let resolution = RecordDraftResolutionService.resolve(
                RecordDraftResolutionInput(
                    rawTitle: draft.title,
                    fallbackCategory: draft.category,
                    amount: draft.amount,
                    date: draft.date,
                    merchantBrandId: MerchantBrandCatalog.matchBrand(in: draft.title)?.id,
                    categoryLockedByUser: true,
                    userEditedTitle: true,
                    source: "ai_command"
                )
            )
            let emotionTag = memoryEnhancedEmotionTag(
                title: resolution.title,
                category: resolution.category,
                amount: draft.amount,
                date: draft.date,
                baseEmotionTag: resolution.emotionTag,
                existingItems: memorySeedItems
            )
            let item = HomeItem(
                title: resolution.title,
                amount: draft.amount,
                category: resolution.category,
                source: .manual,
                createdAt: draft.date,
                updatedAt: now,
                emotionTag: emotionTag,
                merchantBrandId: resolution.merchantBrandId,
                userEditedTitle: true,
                userEditedCategory: true,
                memoryContext: memoryContextForRecord(date: draft.date)
            )
            memorySeedItems.insert(item, at: 0)
            return item
        }

        items.insert(contentsOf: importedItems, at: 0)
        persistItems()
        analyticsService.track(
            "ai_command_records_saved",
            props: [
                "count": String(importedItems.count),
                "source": "ai_command",
            ]
        )
        refreshTodayPlayback()
        if wasEmpty {
            emitRouteGuidance(.firstRecordTodayPlayback)
        } else {
            refreshRouteGuidanceIfNeeded()
        }
        if let firstItem = importedItems.first {
            enqueuePetMessage(for: firstItem)
        }
        Task {
            for item in importedItems {
                await syncUpsertToCloud(item)
            }
        }
        return importedItems.count
    }

    private func updateOCRSuccessStatus(prefix: String, isMember: Bool) {
        let remaining = dailyQuotaStore.ocrRemaining(isMember: false)
        ocrStatus = ExperienceRuleCopy.ocrSuccessMessage(
            prefix: prefix,
            remaining: remaining,
            isMember: isMember
        )
    }

    func updateOCRDraftStatus(id: UUID, isResolved: Bool) {
        guard let idx = items.firstIndex(where: { $0.id == id }), items[idx].draftMeta != nil else { return }
        items[idx].draftMeta?.status = isResolved ? .resolved : .pending
        items[idx].updatedAt = Date()
        persistItems()
        clearOCRStatusIfNoPendingDrafts()
        Task { await syncUpsertToCloud(items[idx]) }
    }

    private func clearOCRStatusIfNoPendingDrafts() {
        guard !items.contains(where: { $0.source == .ocr && $0.draftMeta?.status == .pending }) else { return }
        ocrStatus = ""
    }

    func clearOCRRecognitionStatus() {
        ocrStatus = ""
    }

    private func brandCategory(for brandId: String?) -> HomeItem.Category? {
        MerchantBrandCatalog.definition(for: brandId)?.category
    }

    private func reviewedOCRDraft(_ draft: OCRReceiptDraft) -> OCRReceiptDraft {
        var reviewed = draft
        let brand = MerchantBrandCatalog.definition(for: draft.merchantBrandId)
            ?? MerchantBrandCatalog.matchOCRBrand(in: "\(draft.title)\n\(draft.rawText)")
        if reviewed.merchantBrandId == nil {
            reviewed.merchantBrandId = brand?.id
        }
        guard reviewed.userEditedCategory != true else { return reviewed }

        if let brand {
            reviewed.category = brand.category
            return reviewed
        }

        let semanticCandidate = HomeItem(
            title: "\(draft.title)\n\(draft.rawText)",
            amount: draft.amount,
            category: draft.category,
            source: .ocr,
            createdAt: draft.date,
            merchantBrandId: reviewed.merchantBrandId
        )
        let scene = LifeSceneSemanticService.classify(semanticCandidate)
        if scene.confidenceTier == .strong {
            reviewed.category = scene.category
        }
        return reviewed
    }

    func updateOCRDraftCategory(id: UUID, category: HomeItem.Category) {
        guard let idx = items.firstIndex(where: { $0.id == id }), items[idx].draftMeta != nil else { return }
        let originalCategory = items[idx].category
        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: items[idx].title,
                fallbackCategory: category,
                amount: items[idx].amount,
                date: items[idx].createdAt,
                merchantBrandId: items[idx].merchantBrandId,
                categoryLockedByUser: true,
                userEditedTitle: items[idx].userEditedTitle == true,
                source: "ocrCategory"
            )
        )
        items[idx].title = resolution.title
        items[idx].category = resolution.category
        items[idx].emotionTag = memoryEnhancedEmotionTag(
            title: resolution.title,
            category: resolution.category,
            amount: items[idx].amount,
            date: items[idx].createdAt,
            baseEmotionTag: resolution.emotionTag,
            excluding: items[idx].id
        )
        items[idx].merchantBrandId = resolution.merchantBrandId
        items[idx].userEditedCategory = true
        if items[idx].memoryContext == nil {
            items[idx].memoryContext = memoryContextForRecord(date: items[idx].createdAt)
        }
        if originalCategory != resolution.category {
            items[idx].categoryCorrectionFrom = originalCategory
        }
        items[idx].updatedAt = Date()
        persistItems()
        Task { await syncUpsertToCloud(items[idx]) }
    }

    func updateOCRDraftAmount(id: UUID, amount: Double) {
        guard amount > 0,
              let idx = items.firstIndex(where: { $0.id == id }),
              items[idx].draftMeta != nil else { return }
        items[idx].amount = amount
        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: items[idx].title,
                fallbackCategory: items[idx].category,
                amount: amount,
                date: items[idx].createdAt,
                merchantBrandId: items[idx].merchantBrandId,
                categoryLockedByUser: true,
                userEditedTitle: items[idx].userEditedTitle == true,
                source: "ocrAmount"
            )
        )
        items[idx].title = resolution.title
        items[idx].category = resolution.category
        items[idx].emotionTag = memoryEnhancedEmotionTag(
            title: resolution.title,
            category: resolution.category,
            amount: amount,
            date: items[idx].createdAt,
            baseEmotionTag: resolution.emotionTag,
            excluding: items[idx].id
        )
        items[idx].merchantBrandId = resolution.merchantBrandId
        items[idx].userEditedCategory = items[idx].userEditedCategory == true ? true : nil
        if items[idx].memoryContext == nil {
            items[idx].memoryContext = memoryContextForRecord(date: items[idx].createdAt)
        }
        items[idx].updatedAt = Date()
        persistItems()
        Task { await syncUpsertToCloud(items[idx]) }
    }

    func deleteOCRDraftItem(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }), items[idx].draftMeta != nil else { return }
        items.remove(at: idx)
        persistItems()
        clearOCRStatusIfNoPendingDrafts()
        analyticsService.track("ocr_draft_deleted")
        refreshTodayPlayback()
        Task { await syncDeleteFromCloud(id: id) }
    }

    func clearResolvedOCRDrafts() {
        var changedItems: [HomeItem] = []
        for idx in items.indices where items[idx].draftMeta?.status == .resolved {
            items[idx].draftMeta = nil
            items[idx].updatedAt = Date()
            changedItems.append(items[idx])
        }
        clearOCRStatusIfNoPendingDrafts()
        guard !changedItems.isEmpty else { return }
        persistItems()
        analyticsService.track("ocr_drafts_resolved", props: ["count": String(changedItems.count)])
        Task {
            for item in changedItems {
                await syncUpsertToCloud(item)
            }
        }
    }

    func resolveAllPendingOCRDrafts() {
        var changedItems: [HomeItem] = []
        for idx in items.indices where items[idx].draftMeta?.status == .pending {
            items[idx].draftMeta?.status = .resolved
            items[idx].updatedAt = Date()
            changedItems.append(items[idx])
        }
        guard !changedItems.isEmpty else { return }
        persistItems()
        clearOCRStatusIfNoPendingDrafts()
        analyticsService.track("ocr_drafts_resolve_all", props: ["count": String(changedItems.count)])
        Task {
            for item in changedItems {
                await syncUpsertToCloud(item)
            }
        }
    }

    func delete(at offsets: IndexSet) {
        let deletedIDs = offsets.compactMap { items.indices.contains($0) ? items[$0].id : nil }
        items.remove(atOffsets: offsets)
        persistItems()
        analyticsService.track("record_deleted_batch", props: ["count": String(deletedIDs.count)])
        refreshTodayPlayback()
        Task {
            for id in deletedIDs {
                await syncDeleteFromCloud(id: id)
            }
        }
    }

    @discardableResult
    func updateItem(_ updated: HomeItem) -> Bool {
        guard let idx = items.firstIndex(where: { $0.id == updated.id }) else { return false }
        let original = items[idx]
        var resolved = updated
        let titleResult = UserContentRiskService.shared.validateManualNote(updated.title, allowEmpty: false)
        guard titleResult.isAllowed else {
            recordInputMessage = titleResult.message
            return false
        }
        recordInputMessage = nil
        let cleanTitle = titleResult.value
        let matchedBrand = MerchantBrandCatalog.matchBrand(in: cleanTitle)
        let brandId = matchedBrand?.id ?? updated.merchantBrandId
        let categoryWasEdited = updated.category != original.category
        let categoryOverridesBrand = brandCategory(for: brandId).map { updated.category != $0 } ?? false
        let titleWasEdited = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            != original.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldTreatTitleAsUserEdited = resolved.userEditedTitle == true || titleWasEdited
        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: cleanTitle,
                fallbackCategory: updated.category,
                amount: resolved.amount,
                date: resolved.createdAt,
                merchantBrandId: brandId,
                categoryLockedByUser: categoryWasEdited || categoryOverridesBrand,
                userEditedTitle: shouldTreatTitleAsUserEdited,
                source: "edit"
            )
        )
        resolved.title = resolution.title
        resolved.category = resolution.category
        if resolved.memoryContext == nil,
           Calendar.current.isDate(resolved.createdAt, inSameDayAs: original.createdAt) {
            resolved.memoryContext = original.memoryContext
        }
        resolved.emotionTag = memoryEnhancedEmotionTag(
            title: resolution.title,
            category: resolution.category,
            amount: resolved.amount,
            date: resolved.createdAt,
            baseEmotionTag: resolution.emotionTag,
            existingItems: items,
            excluding: resolved.id,
            weatherOverride: storedWeatherSnapshot(from: resolved.memoryContext),
            allowLiveWeather: false
        )
        resolved.merchantBrandId = resolution.merchantBrandId
        if resolved.userEditedTitle == true || titleWasEdited {
            resolved.userEditedTitle = true
        }
        if original.userEditedCategory == true || categoryWasEdited {
            resolved.userEditedCategory = true
        }
        if categoryWasEdited {
            resolved.categoryCorrectionFrom = original.category
            resolved.scenePackId = nil
        } else if original.categoryCorrectionFrom != nil {
            resolved.categoryCorrectionFrom = original.categoryCorrectionFrom
        }
        items[idx] = resolved
        persistItems()
        analyticsService.track("record_updated", props: [
            "category": resolved.category.rawValue,
            "amount": String(format: "%.2f", resolved.amount)
        ])
        refreshTodayPlayback()
        Task { await syncUpsertToCloud(resolved) }
        return true
    }

    @discardableResult
    func attachMemoryImage(_ imageData: Data, to itemID: UUID) -> Bool {
        attachMemoryImages([imageData], to: itemID)
    }

    @discardableResult
    func attachMemoryImages(_ imageDatas: [Data], to itemID: UUID) -> Bool {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return false }
        var images = items[idx].memoryImages
        let availableSlots = max(0, 9 - images.count)
        let cleanImages = Array(imageDatas.filter { !$0.isEmpty }.prefix(availableSlots))
        guard !cleanImages.isEmpty else { return false }
        images.append(contentsOf: cleanImages)
        items[idx].memoryImages = images
        items[idx].updatedAt = Date()
        let updated = items[idx]
        persistItems()
        analyticsService.track("record_memory_image_attached", props: [
            "category": updated.category.rawValue,
            "amount": String(format: "%.2f", updated.amount),
            "image_count": String(cleanImages.count)
        ])
        refreshTodayPlayback()
        Task { await syncUpsertToCloud(updated) }
        return true
    }

    @discardableResult
    func removeMemoryImage(from itemID: UUID) -> Bool {
        removeMemoryImage(at: 0, from: itemID)
    }

    @discardableResult
    func removeMemoryImage(at imageIndex: Int, from itemID: UUID) -> Bool {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return false }
        var images = items[idx].memoryImages
        guard images.indices.contains(imageIndex) else { return false }
        images.remove(at: imageIndex)
        items[idx].memoryImages = images
        items[idx].updatedAt = Date()
        let updated = items[idx]
        persistItems()
        analyticsService.track("record_memory_image_removed", props: [
            "category": updated.category.rawValue,
            "amount": String(format: "%.2f", updated.amount),
            "remaining_image_count": String(updated.memoryImages.count)
        ])
        refreshTodayPlayback()
        Task { await syncUpsertToCloud(updated) }
        return true
    }

    func syncCloudLedgerNow() async {
        let context = cloudContext()
        guard let context else {
            syncStatusMessage = "当前只保存在本机。登录并开启云端备份后，可以同步到云端。"
            return
        }
        isSyncingCloudLedger = true
        defer { isSyncingCloudLedger = false }
        let service = LedgerSyncService(baseURL: context.baseURL, accessToken: context.accessToken)
        do {
            let remoteItems = try await service.fetchAll().sorted { $0.createdAt > $1.createdAt }
            let merged = mergeLedgers(local: items, remote: remoteItems).sorted { $0.createdAt > $1.createdAt }
            items = merged
            persistItems()
            // Re-upload merged result to converge both sides (idempotent upsert).
            for item in merged {
                try? await service.upload(item)
            }
            syncStatusMessage = "账本已同步。重复的记录已自动保留最新版本。"
        } catch {
            syncStatusMessage = "同步没有完成，请稍后再试。你的本机记录已保留。"
        }
    }

    func generateMonthlyInsight(settings: AppSettings) async -> MonthlyInsightReport {
        isGeneratingMonthlyInsight = true
        insightErrorMessage = nil
        defer { isGeneratingMonthlyInsight = false }

        let local = localMonthlyInsightBlocks()
        var report = MonthlyInsightReport(
            summary: local.summary,
            structure: local.structure,
            advice: local.advice,
            source: .fallback
        )

        if settings.useRemoteAI {
            let apiKey = KeychainService.loadAIAPIKey()
            let endpoint = settings.aiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            let isDirectModelEndpoint = endpoint.isEmpty || endpoint.contains("open.bigmodel.cn")
            if AIUsageLimiter.canUseRemoteAI(limitPerMonth: settings.remoteAIMonthlyLimit),
               !(isDirectModelEndpoint && apiKey.isEmpty) {
                let monthItems = filteredItems(in: .month).filter { $0.amount > 0 }
                let grouped = Dictionary(grouping: monthItems, by: \.category)
                    .map { key, value in
                        (category: key, amount: value.reduce(0) { $0 + $1.amount })
                    }
                    .sorted { $0.amount > $1.amount }
                let monthKey = Self.monthKey(for: .now)
                let snapshot = AISnapshot(
                    date: monthKey,
                    todayTotal: todayExpenseTotal,
                    weekAverage: weeklyAverageExpense(),
                    monthTotal: monthExpenseTotal,
                    topCategories: grouped.prefix(3).map { $0.category.rawValue }
                )
                do {
                    let payload = try await aiReportService.generateInsight(
                        snapshot: snapshot,
                        endpoint: endpoint,
                        apiKey: apiKey,
                        tone: settings.aiTone,
                        model: settings.aiModel,
                        feature: "monthly"
                    )
                    report = MonthlyInsightReport(
                        summary: payload.summary,
                        structure: payload.action,
                        advice: payload.encourage,
                        source: .live
                    )
                    _ = AIUsageLimiter.consumeOnce(limitPerMonth: settings.remoteAIMonthlyLimit)
                } catch {
                    insightErrorMessage = remoteAIInsightFallbackMessage(for: error)
                    report.source = .errorFallback
                }
            } else {
                insightErrorMessage = !AIUsageLimiter.canUseRemoteAI(limitPerMonth: settings.remoteAIMonthlyLimit)
                    ? "本月远程 AI 配额已达上限。"
                    : "直连模型需要 API Key，已回退本地建议。"
                report.source = .errorFallback
            }
        }

        analyticsService.track(
            "ai_monthly_generated",
            props: [
                "mode": report.source.analyticsValue,
                "items": String(filteredItems(in: .month).count),
            ]
        )
        triggerMemberNudge(scene: .aiMonthly)
        return report
    }

    var recordLearningHint: String? {
        let normalizedAmount = inputAmount.replacingOccurrences(of: ",", with: "")
        guard let amount = Double(normalizedAmount), amount > 0 else { return nil }

        let noteResult = UserContentRiskService.shared.validateManualNote(inputTitle, allowEmpty: true)
        let trimmedNote = noteResult.isAllowed ? noteResult.value : ""

        if categoryLockedByUser {
            return "这次按「\(selectedCategory.label)」放好。"
        }
        if MerchantBrandCatalog.matchBrand(in: trimmedNote) != nil {
            return nil
        }
        if semanticCategory(from: trimmedNote) != nil {
            return nil
        }
        guard let result = recordPrefillResult,
              let recordPrefillAmount,
              abs(recordPrefillAmount - amount) < 0.005 else {
            return items.count < 6 ? "先帮你放到合适分类。" : nil
        }

        switch result.source {
        case "scene_habit":
            if result.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return "这个时间附近常这样记。"
            }
            if let category = result.category {
                if category == .other {
                    return "还没看出明确场景，先放到「其他」。"
                }
                return "这个时间附近常是「\(category.label)」。"
            }
            return nil
        case "habit":
            if let category = result.category {
                if category == .other {
                    return "还没看出明确场景，先放到「其他」。"
                }
                return "这个时间附近常是「\(category.label)」。"
            }
            return nil
        case "frequent":
            if let category = result.category {
                if category == .other {
                    return "还没看出明确场景，先放到「其他」。"
                }
                return "这个时间附近常是「\(category.label)」。"
            }
            return nil
        case "generic":
            return items.count < 6
                ? "先帮你放到合适分类。"
                : nil
        case "brand":
            return nil
        default:
            return nil
        }
    }

    private func enqueuePetMessage(for record: HomeItem) {
        let settings = LocalStore.loadSettings()
        guard settings.petCompanionEnabled else {
            petMessage = nil
            return
        }
        let currentItems = items
        let cachedWeather = WeatherCompanionService.shared.cachedSnapshot
        Task {
            let message = await petCompanionService.buildContextualMessage(
                record: record,
                weather: cachedWeather,
                settings: settings,
                todayItems: currentItems
            )
            if let message, LocalStore.loadSettings().petCompanionEnabled {
                petMessage = message
            }
            if settings.weatherCompanionEnabled {
                WeatherCompanionService.shared.refreshWeatherInBackground(refreshGeo: false)
            }
        }
    }

    func recommendCategory(for amountText: String) -> HomeItem.Category? {
        recommendCategoryResult(for: amountText)?.recommended
    }

    func recommendCategoryResult(for amountText: String) -> CategoryRecommendResult? {
        let normalizedAmount = amountText.replacingOccurrences(of: ",", with: "")
        guard let amount = Double(normalizedAmount), amount > 0 else { return nil }
        let noteResult = UserContentRiskService.shared.validateManualNote(inputTitle, allowEmpty: true)
        let trimmedNote = noteResult.isAllowed ? noteResult.value : ""
        let brand = MerchantBrandCatalog.matchBrand(in: trimmedNote)
        let noteSemanticCategory = semanticCategory(from: trimmedNote)
        if !categoryLockedByUser {
            if let brand {
                if MerchantBrandCatalog.isConvenienceStoreBrand(brand),
                   let noteSemanticCategory,
                   noteSemanticCategory != brand.category {
                    return CategoryRecommendResult(recommended: noteSemanticCategory, reasonTag: "semantic")
                }
                return CategoryRecommendResult(recommended: brand.category, reasonTag: "brand")
            }
            if let noteSemanticCategory {
                return CategoryRecommendResult(recommended: noteSemanticCategory, reasonTag: "semantic")
            }
        }
        if !categoryLockedByUser,
           let category = recordPrefillResult?.category,
           recordPrefillResult?.source != "generic",
           let recordPrefillAmount,
           abs(recordPrefillAmount - amount) < 0.005,
           (recordPrefillResult?.confidence ?? 0) >= 0.55 {
            return CategoryRecommendResult(recommended: category, reasonTag: recordPrefillResult?.source)
        }
        if let frequentSuggestion = frequentRecordAmountSuggestion(for: amount, at: selectedDate),
           frequentSuggestionCanOverrideNote(frequentSuggestion, note: trimmedNote),
           !categoryLockedByUser {
            return CategoryRecommendResult(recommended: frequentSuggestion.category, reasonTag: "frequent")
        }
        if !categoryLockedByUser,
           let category = recordPrefillResult?.category,
           recordPrefillResult?.source == "generic",
           let recordPrefillAmount,
           abs(recordPrefillAmount - amount) < 0.005 {
            return CategoryRecommendResult(recommended: category, reasonTag: recordPrefillResult?.source)
        }
        guard !trimmedNote.isEmpty else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
        let recentItems = items.filter { $0.createdAt >= start && $0.amount > 0 }
        return categoryRecommendService.recommend(
            input: CategoryRecommendInput(
                amount: amount,
                referenceDate: selectedDate,
                items: recentItems,
                noteDraft: trimmedNote,
                locked: categoryLockedByUser,
                context: currentRecordContextSignal()
            )
        )
    }

    private func currentRecordContextSignal() -> RecordContextSignal {
        let settings = LocalStore.loadSettings()
        // Coarse local context only: cached weather plus time bands, no location trail or POI.
        let weather = settings.weatherCompanionEnabled && shouldAttachLiveContext(to: selectedDate)
            ? WeatherCompanionService.shared.cachedSnapshot
            : nil
        return RecordContextSignal(referenceDate: selectedDate, weather: weather)
    }

    private func memoryContextForRecord(date: Date) -> HomeItem.MemoryContext? {
        let settings = LocalStore.loadSettings()
        guard settings.weatherCompanionEnabled,
              shouldAttachLiveContext(to: date) else {
            return nil
        }
        let weather = WeatherCompanionService.shared.cachedSnapshot
        let city = WeatherCompanionService.shared.cachedCitySemanticSnapshot
        let context = HomeItem.MemoryContext(
            weatherKind: RecordMemoryContextService.weatherKindCode(from: weather),
            temperatureCelsius: weather?.temp,
            cityName: city?.cityName,
            semanticPlace: city?.semanticPlace
        )
        let hasValue = context.weatherKind != nil
            || context.temperatureCelsius != nil
            || context.cityName != nil
            || context.semanticPlace != nil
        return hasValue ? context : nil
    }

    private func memoryEnhancedEmotionTag(
        title: String,
        category: HomeItem.Category,
        amount: Double,
        date: Date,
        baseEmotionTag: String,
        existingItems: [HomeItem]? = nil,
        excluding excludedID: UUID? = nil,
        weatherOverride: WeatherSnapshot? = nil,
        allowLiveWeather: Bool = true
    ) -> String {
        let settings = LocalStore.loadSettings()
        let weather = weatherOverride ?? (allowLiveWeather && settings.weatherCompanionEnabled && shouldAttachLiveContext(to: date)
            ? WeatherCompanionService.shared.cachedSnapshot
            : nil)
        let memoryItems = (existingItems ?? items).filter { item in
            guard let excludedID else { return true }
            return item.id != excludedID
        }
        return RecordMemoryContextService.enhancedEmotionTag(
            input: RecordMemoryContextInput(
                title: title,
                category: category,
                amount: amount,
                date: date,
                baseEmotionTag: baseEmotionTag,
                existingItems: memoryItems,
                weather: weather
            )
        )
    }

    private func storedWeatherSnapshot(from context: HomeItem.MemoryContext?) -> WeatherSnapshot? {
        guard let context else { return nil }
        let code: Int?
        switch context.weatherKind {
        case "rain":
            code = 61
        case "snow":
            code = 71
        case "hot", "cold", "normal":
            code = nil
        default:
            code = nil
        }
        guard code != nil || context.temperatureCelsius != nil else { return nil }
        return WeatherSnapshot(
            temp: context.temperatureCelsius,
            weatherCode: code,
            ts: Date()
        )
    }

    private func shouldAttachLiveContext(to date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }

    func refreshRecordPrefill() {
        let normalizedAmount = inputAmount.replacingOccurrences(of: ",", with: "")
        guard let amount = Double(normalizedAmount), amount > 0 else {
            recordPrefillResult = nil
            recordPrefillAmount = nil
            return
        }

        let noteResult = UserContentRiskService.shared.validateManualNote(inputTitle, allowEmpty: true)
        let trimmedNote = noteResult.isAllowed ? noteResult.value : ""
        let brand = MerchantBrandCatalog.matchBrand(in: trimmedNote)
        let frequentSuggestion = frequentRecordAmountSuggestion(for: amount, at: selectedDate)
        let noteSemanticCategory = semanticCategory(from: trimmedNote)
        let shouldUseBrandPrefill = brand.map { brand in
            !MerchantBrandCatalog.isConvenienceStoreBrand(brand)
                || noteSemanticCategory == nil
                || noteSemanticCategory == brand.category
        } ?? false

        let start = Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? .distantPast
        let recentItems = items.filter { $0.createdAt >= start && $0.amount > 0 }
        let result = recordPrefillService.prefill(
            input: RecordPrefillInput(
                amount: amount,
                referenceDate: selectedDate,
                items: recentItems,
                noteDraft: trimmedNote,
                categoryLocked: categoryLockedByUser,
                merchantBrandId: categoryLockedByUser || !shouldUseBrandPrefill ? nil : brand?.id,
                context: currentRecordContextSignal()
            )
        )
        recordPrefillResult = result
        recordPrefillAmount = amount

        if result == nil,
           brand == nil,
           noteSemanticCategory == nil,
           let frequentSuggestion,
           frequentSuggestionCanOverrideNote(frequentSuggestion, note: trimmedNote) {
            let title = frequentHabitTitle(
                for: frequentSuggestion,
                amount: amount,
                at: selectedDate
            )
            recordPrefillResult = RecordPrefillResult(
                category: frequentSuggestion.category,
                title: title,
                emotionTag: habitEmotionTag(
                    title: title,
                    category: frequentSuggestion.category,
                    amount: amount,
                    date: selectedDate
                ),
                confidence: frequentSuggestion.confidence,
                source: "frequent"
            )
        }

        if let category = resolvePrefillCategory(
            brand: brand,
            frequent: frequentSuggestion,
            semanticCategory: noteSemanticCategory,
            habitResult: result
        ) {
            applyRecommendedCategory(category)
        }
        recordPrefillResult = sanitizedPrefillResult(
            recordPrefillResult,
            for: selectedCategory
        )
    }

    private func sanitizedPrefillResult(
        _ result: RecordPrefillResult?,
        for category: HomeItem.Category
    ) -> RecordPrefillResult? {
        guard let result else { return nil }
        guard let title = result.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return result
        }
        guard RecordSemanticLexicon.canDisplayPrefillTitle(
            title,
            category: category,
            source: result.source
        ) else {
            return RecordPrefillResult(
                category: result.category,
                title: nil,
                emotionTag: nil,
                confidence: result.confidence,
                source: result.source
            )
        }
        return result
    }

    private func resolvePrefillCategory(
        brand: MerchantBrandDefinition?,
        frequent: FrequentRecordAmountSuggestion?,
        semanticCategory: HomeItem.Category?,
        habitResult: RecordPrefillResult?
    ) -> HomeItem.Category? {
        guard !categoryLockedByUser else { return nil }
        // Cascade order is intentionally single-apply:
        // brand > explicit note semantics > confident frequent exact amount in the same time context > habit >= 0.55 > generic category fallback.
        // TODO(next PR): make habit exact-amount grouping share the same source as frequent, replacing the current ±30% loose match.
        if let brand { return brand.category }
        if let semanticCategory {
            return semanticCategory
        }
        if let frequent {
            return frequent.category
        }
        if let category = habitResult?.category,
           habitResult?.source == "generic" {
            return category
        }
        if let category = habitResult?.category,
           habitResult?.source != "generic",
           (habitResult?.confidence ?? 0) >= 0.55 {
            return category
        }
        return nil
    }

    private func semanticCategory(from note: String) -> HomeItem.Category? {
        RecordSemanticLexicon.semanticCategory(of: note)
    }

    private func frequentSuggestionCanOverrideNote(
        _ suggestion: FrequentRecordAmountSuggestion,
        note: String
    ) -> Bool {
        guard suggestion.confidence >= 0.67 else { return false }
        let semanticCategories = RecordSemanticLexicon.matchingCategories(in: note)
        guard !semanticCategories.isEmpty else { return true }
        return semanticCategories.contains(suggestion.category)
    }

    func clearRecordInputMessage() {
        guard recordInputMessage != nil else { return }
        recordInputMessage = nil
    }

    func clearLocalLedgerData() {
        items = []
        insights = []
        latestPlayback = nil
        latestActionCard = nil
        activeRouteGuidance = nil
        recordPrefillResult = nil
        recordPrefillAmount = nil
        petMessage = nil
        LocalStore.saveHomeItems([])
        LocalStore.saveDailyInsights([])
        UserDefaults.standard.removeObject(forKey: "latest_action_card_v1")
    }

    func selectCategory(_ category: HomeItem.Category) {
        rememberCategoryCorrectionIfNeeded(to: category)
        selectedCategory = category
        categoryLockedByUser = true
    }

    func preferNoteSemanticsForCurrentDraft() {
        guard categoryLockedByUser || pendingCategoryCorrectionFrom != nil else { return }
        categoryLockedByUser = false
        pendingCategoryCorrectionFrom = nil
    }

    func applyScenePackDraft(title: String, category: HomeItem.Category) {
        rememberCategoryCorrectionIfNeeded(to: category)
        inputTitle = title
        selectedCategory = category
        categoryLockedByUser = true
        recordPrefillResult = nil
        recordPrefillAmount = nil
        recordInputMessage = nil
    }

    func applyScenePackCategory(_ category: HomeItem.Category) {
        rememberCategoryCorrectionIfNeeded(to: category)
        selectedCategory = category
        categoryLockedByUser = true
        recordPrefillResult = nil
        recordPrefillAmount = nil
        recordInputMessage = nil
    }

    func applyRecommendedCategory(_ category: HomeItem.Category) {
        guard !categoryLockedByUser else { return }
        selectedCategory = category
        lastAutoRecommendedCategory = category
    }

    private func rememberCategoryCorrectionIfNeeded(to category: HomeItem.Category) {
        guard !categoryLockedByUser else { return }
        let previous = lastAutoRecommendedCategory ?? selectedCategory
        guard previous != .other, previous != category else { return }
        pendingCategoryCorrectionFrom = previous
    }

    func updateSelectedDate(_ date: Date, userInitiated: Bool) {
        selectedDate = date
        if userInitiated {
            selectedDateEditedByUser = true
        }
    }

    func refreshDraftSelectedDate(now: Date = .now, force: Bool = false) {
        guard !selectedDateEditedByUser else { return }
        guard force || abs(now.timeIntervalSince(selectedDate)) >= 30 else { return }
        selectedDate = now
    }

    func noteSuggestions(for category: HomeItem.Category, at date: Date = .now) -> [String] {
        let defaults: [String]
        switch category {
        case .dining:
            let hour = Calendar.current.component(.hour, from: date)
            switch hour {
            case 5..<10:
                defaults = ["早餐路上买点吃的", "早班前续一杯咖啡", "出门前吃一口热的"]
            case 10..<14:
                defaults = ["午间简单吃一顿", "食堂一份热饭", "饭点买杯喝的"]
            case 14..<17:
                defaults = ["下午续一杯咖啡", "便利店买点轻食", "忙到一半补一口"]
            case 17..<21:
                defaults = ["晚餐吃一顿热饭", "下班后吃点热乎的", "和人一起吃晚饭"]
            default:
                defaults = ["加班后吃点热乎的", "晚归路上的一口热食", "深夜买点小食"]
            }
        case .transport:
            defaults = ["地铁到站，路上这一段", "打车走完这一程", "停车和油费记一笔"]
        case .shopping:
            defaults = ["下单一个需要的", "买到常用的小东西", "快递路上记一笔"]
        case .daily:
            defaults = ["便利店补一袋日常", "超市买点家里要用的", "日用品刚好补上"]
        case .entertainment:
            defaults = ["买了这场电影票", "游戏里充了一笔", "周末出去坐一会儿"]
        case .lodging:
            defaults = ["今晚住在这里", "出差住宿记一笔", "短住一晚记下"]
        case .health:
            defaults = healthNoteSuggestions()
        case .home:
            defaults = ["水电燃气交上了", "家里添个要用的", "修修补补记一笔"]
        case .social:
            defaults = ["见面带点东西", "和朋友吃了一顿", "探望时买点东西"]
        case .other:
            defaults = ["临时花了一笔", "还没想好归哪类", "先把这笔记下"]
        }
        guard let prefill = compatiblePrefillTitleForSave(category: category) else {
            return defaults
        }
        return uniqueNoteSuggestions([prefill] + defaults)
    }

    private func healthNoteSuggestions() -> [String] {
        let title = inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if containsFitnessCue(title) {
            return ["运动前小准备", "运动后补给一下", "一场运动记下来"]
        }
        return ["药店补点常备药", "问诊挂号记一笔", "体检项目记下来"]
    }

    private func containsFitnessCue(_ text: String) -> Bool {
        let cues = ["运动", "健身", "锻炼", "训练", "跑步", "瑜伽", "游泳", "球场", "课程", "护具", "运动鞋", "运动服", "补给", "恢复", "能量", "月卡", "年卡"]
        return cues.contains { text.contains($0) }
    }

    private func uniqueNoteSuggestions(_ suggestions: [String]) -> [String] {
        var seen = Set<String>()
        return suggestions.filter { suggestion in
            let trimmed = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return false }
            seen.insert(trimmed)
            return true
        }
    }

    func frequentRecordAmounts(at date: Date = .now) -> [Double] {
        frequentRecordAmountSuggestions(at: date).map(\.amount)
    }

    func frequentRecordAmountSuggestions(at date: Date = .now) -> [FrequentRecordAmountSuggestion] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -180, to: date) ?? .distantPast
        let recentItems = items.filter { item in
            item.amount > 0 && item.createdAt >= start && item.createdAt <= date
        }
        guard recentItems.count >= 6 else { return [] }

        let targetBucket = hourHabitBucket(for: date)
        let targetWeekend = isHabitWeekend(date)
        let contextItems = recentItems.filter { item in
            hourHabitBucket(for: item.createdAt) == targetBucket &&
            isHabitWeekend(item.createdAt) == targetWeekend
        }
        guard contextItems.count >= 3 else { return [] }

        let grouped = Dictionary(grouping: contextItems) { item in
            Int((item.amount * 100).rounded())
        }

        let candidates: [FrequentRecordAmountSuggestion] = grouped.compactMap { entry in
            let cents = entry.key
            let group = entry.value
            let latestDate = group.map { $0.createdAt }.max() ?? .distantPast
            guard let category = frequentCategory(in: group) else { return nil }
            return FrequentRecordAmountSuggestion(
                amount: Double(cents) / 100,
                category: category.category,
                count: category.count,
                confidence: category.confidence,
                latest: latestDate
            )
        }

        let validCandidates = candidates.filter { candidate in
            candidate.count >= 2 &&
            candidate.confidence >= 0.75 &&
            candidate.amount > 0 &&
            candidate.amount <= 9999
        }

        let sortedCandidates = validCandidates.sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.latest > rhs.latest
            }
            return lhs.count > rhs.count
        }

        return Array(sortedCandidates.prefix(3))
    }

    private func frequentRecordAmountSuggestion(for amount: Double, at date: Date) -> FrequentRecordAmountSuggestion? {
        frequentRecordAmountSuggestions(at: date).first { suggestion in
            abs(suggestion.amount - amount) < 0.005
        }
    }

    private func frequentHabitTitle(
        for suggestion: FrequentRecordAmountSuggestion,
        amount: Double,
        at date: Date
    ) -> String? {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -180, to: date) ?? .distantPast
        let amountCents = Int((amount * 100).rounded())
        let supportItems = items.filter { item in
            item.amount > 0
                && item.createdAt >= start
                && item.createdAt <= date
                && item.category == suggestion.category
                && Int((item.amount * 100).rounded()) == amountCents
                && hourHabitBucket(for: item.createdAt) == hourHabitBucket(for: date)
                && isHabitWeekend(item.createdAt) == isHabitWeekend(date)
        }
        guard supportItems.count >= 2 else { return nil }

        let ranked = supportItems.reduce(into: [String: Int]()) { result, item in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard RecordPrefillService.isHabitTitle(title, category: suggestion.category),
                  RecordSemanticLexicon.canReuseHabitTitle(
                    title,
                    category: suggestion.category,
                    userEditedTitle: item.userEditedTitle == true
                  ) else {
                return
            }
            result[title, default: 0] += item.userEditedTitle == true ? 2 : 1
        }
        .sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }
            return lhs.value > rhs.value
        }

        guard let best = ranked.first, best.value >= 2 else { return nil }
        return best.key
    }

    private func habitEmotionTag(
        title: String?,
        category: HomeItem.Category,
        amount: Double,
        date: Date
    ) -> String? {
        guard let title = title,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return NarrativeCopyResolver.resolveEmotionTag(
            context: NarrativeCopyResolver.Context(
                brandId: nil,
                category: category,
                amount: amount,
                date: date,
                seed: title,
                note: title
            )
        )
    }

    private func frequentCategory(in items: [HomeItem]) -> (category: HomeItem.Category, count: Int, confidence: Double)? {
        if let scene = LifeSceneSemanticService.dominantScene(in: items),
           scene.signal.confidenceTier >= .medium,
           scene.count >= 2 {
            let confidence = Double(scene.count) / Double(max(items.count, 1))
            if confidence >= 0.67 {
                return (scene.signal.category, scene.count, confidence)
            }
        }

        struct CategoryCandidate {
            let category: HomeItem.Category
            let count: Int
            let latest: Date
        }

        let ranked = Dictionary(grouping: items, by: \.category)
            .map { entry in
                CategoryCandidate(
                    category: entry.key,
                    count: entry.value.count,
                    latest: entry.value.map(\.createdAt).max() ?? .distantPast
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.latest > rhs.latest
                }
                return lhs.count > rhs.count
            }
        guard let top = ranked.first else { return nil }
        let secondCount = ranked.dropFirst().first?.count ?? 0
        let confidence = Double(top.count) / Double(max(items.count, 1))
        guard top.count >= 2, confidence >= 0.75, top.count >= secondCount + 2 else {
            return nil
        }
        return (top.category, top.count, confidence)
    }

    private func hourHabitBucket(for date: Date) -> Int {
        Calendar.current.component(.hour, from: date) / 3
    }

    private func isHabitWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    var todayItems: [HomeItem] {
        ensureItemDerivedCacheFresh()
        return itemDerivedCache.todayPositiveItems
    }

    var recentThreeItems: [HomeItem] {
        ensureItemDerivedCacheFresh()
        return itemDerivedCache.recentThreeTodayItems
    }

    var currentYearItems: [HomeItem] {
        ensureItemDerivedCacheFresh()
        return itemDerivedCache.currentYearItems
    }

    var periodItems: [HomeItem] {
        filteredItems(in: selectedPeriod)
    }

    var categorySummary: [(category: HomeItem.Category, amount: Double, ratio: Double)] {
        let targetItems = periodItems
        let total = targetItems.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return [] }

        let grouped = Dictionary(grouping: targetItems, by: \.category)
            .map { key, value in
                let amount = value.reduce(0) { $0 + $1.amount }
                return (category: key, amount: amount, ratio: amount / total)
            }
            .sorted { $0.amount > $1.amount }
        return grouped
    }

    var todayInsight: DailyInsight? {
        let key = Self.dayKey(for: .now)
        return insights.first(where: { $0.dayKey == key })
    }

    func generateDailyInsight(userName: String, settings: AppSettings) async {
        let key = Self.dayKey(for: .now)
        let todayItems = items.filter { Calendar.current.isDateInToday($0.createdAt) }
        let snapshotSignature = dailyInsightSnapshotSignature(for: todayItems, dayKey: key)
        if let existing = insights.first(where: { $0.dayKey == key }),
           existing.snapshotSignature == snapshotSignature {
            return
        }
        guard !isGeneratingInsight else { return }
        insights.removeAll { $0.dayKey == key }
        persistInsights()

        isGeneratingInsight = true
        insightErrorMessage = nil

        let todayTotal = todayItems.reduce(0) { $0 + $1.amount }
        let weeklyAverage = weeklyAverageExpense()
        let topCategory = todayItems
            .reduce(into: [HomeItem.Category: Double]()) { partialResult, item in
                partialResult[item.category, default: 0] += item.amount
            }
            .max(by: { $0.value < $1.value })?.key.rawValue ?? "无"

        if settings.useRemoteAI {
            let apiKey = KeychainService.loadAIAPIKey()
            let isDirectModelEndpoint = settings.aiEndpoint.isEmpty || settings.aiEndpoint.contains("open.bigmodel.cn")
            if !AIUsageLimiter.canUseRemoteAI(limitPerMonth: settings.remoteAIMonthlyLimit) {
                insightErrorMessage = "本月远程 AI 配额已达上限，已回退本地建议。"
            } else if isDirectModelEndpoint && apiKey.isEmpty {
                insightErrorMessage = "直连模型需要 API Key，已回退本地建议。"
            } else {
            let snapshot = AISnapshot(
                date: key,
                todayTotal: todayTotal,
                weekAverage: weeklyAverage,
                monthTotal: monthExpenseTotal,
                topCategories: categorySummary.prefix(3).map(\.category.rawValue)
            )
            do {
                let payload = try await aiReportService.generateInsight(
                    snapshot: snapshot,
                    endpoint: settings.aiEndpoint,
                    apiKey: apiKey,
                    tone: settings.aiTone,
                    model: settings.aiModel,
                    feature: "daily"
                )
                let remoteInsight = DailyInsight(
                    dayKey: key,
                    summary: payload.summary,
                    action: payload.action,
                    encourage: payload.encourage,
                    snapshotSignature: snapshotSignature
                )
                insights.insert(remoteInsight, at: 0)
                persistInsights()
                _ = AIUsageLimiter.consumeOnce(limitPerMonth: settings.remoteAIMonthlyLimit)
                analyticsService.track("ai_daily_generated", props: ["mode": "live", "items": String(todayItems.count)])
                isGeneratingInsight = false
                return
            } catch {
                insightErrorMessage = remoteAIInsightFallbackMessage(for: error)
            }
            }
        }

        let displayName = dailyInsightDisplayName(from: userName)
        let summary = settings.aiTone == .gentle
            ? "\(displayName.map { "\($0)，" } ?? "")今天的记录里「\(topCategory)」最常出现。"
            : "今天更常记录到「\(topCategory)」。"

        let action: String
        if todayTotal > weeklyAverage && weeklyAverage > 0 {
            action = "今天的记录比平时多一点，先把明细留清楚。"
        } else {
            action = "今天这几笔已经留在账本里，明天有新花费再继续记。"
        }

        let encourage = settings.aiTone == .gentle
            ? "先按今天这些记录看，日常会更清楚。"
            : "继续记录，会更容易看清自己的日常。"

        let insight = DailyInsight(
            dayKey: key,
            summary: summary,
            action: action,
            encourage: encourage,
            snapshotSignature: snapshotSignature
        )
        insights.insert(insight, at: 0)
        persistInsights()
        analyticsService.track("ai_daily_generated", props: ["mode": "local_fallback", "items": String(todayItems.count)])
        isGeneratingInsight = false
    }

    private func dailyInsightDisplayName(from userName: String) -> String? {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "叙账用户" else { return nil }
        let compact = trimmed.replacingOccurrences(of: " ", with: "")
        if compact.hasPrefix("用户") {
            let suffix = compact.dropFirst(2)
            if !suffix.isEmpty, suffix.allSatisfy(\.isNumber) {
                return nil
            }
        }
        return trimmed
    }

    private func remoteAIInsightFallbackMessage(for error: Error) -> String {
        let message = error.localizedDescription
        if message.contains("内容保护") || message.contains("隐私") || message.contains("链接") {
            return "远程 AI 已跳过，已回退本地建议。"
        }
        return "远程 AI 暂时不可用，已回退本地建议。"
    }

    func markWeeklyShareGenerated() {
        analyticsService.track("weekly_share_card_generated")
        triggerMemberNudge(scene: .shareSuccess)
    }

    func markWeeklyRhythmReviewed() {
        analyticsService.track("weekly_rhythm_review", props: ["top": weekTopCategoryText])
    }

    func markPlaybackCompleted() {
        analyticsService.track("bill_playback_completed", props: ["count": String(latestPlayback?.entries.count ?? 0)])
        triggerMemberNudge(scene: .playbackComplete)
    }

    func triggerMemberNudge(scene: MemberFlowScene) {
        guard !LocalStore.loadSettings().hasMemberAccess else {
            memberNudgeCopy = nil
            activeMemberNudgeScene = nil
            return
        }
        guard nudgePolicyService.canShow(scene: scene.rawValue) else { return }
        nudgePolicyService.markShown(scene: scene.rawValue)
        memberNudgeCopy = memberFlowService.ctaCopy(scene: scene)
        activeMemberNudgeScene = scene
        analyticsService.track("member_cta_exposed", props: ["scene": scene.rawValue, "channel": "ios_home"])
    }

    func dismissMemberNudge(scene: MemberFlowScene) {
        nudgePolicyService.markDismissed(scene: scene.rawValue)
        memberNudgeCopy = nil
        activeMemberNudgeScene = nil
        analyticsService.track("member_cta_dismissed", props: ["scene": scene.rawValue, "channel": "ios_home"])
    }

    func handleMemberNudgePrimaryAction() {
        guard let scene = activeMemberNudgeScene else { return }
        analyticsService.track("member_cta_clicked", props: ["scene": scene.rawValue, "channel": "ios_home"])
        memberNudgeCopy = nil
        activeMemberNudgeScene = nil
        syncStatusMessage = "已为你打开会员路径：请到设置页完成开通。"
    }

    func consumeRouteGuidance(_ guidance: PlaybackRouteGuidance? = nil) {
        guard let activeRouteGuidance else {
            if let guidance {
                persistRouteGuidanceHandled(guidance)
            }
            return
        }
        if let guidance, guidance != activeRouteGuidance { return }
        persistRouteGuidanceHandled(activeRouteGuidance)
        self.activeRouteGuidance = nil
    }

    func markSummaryPlaybackCompleted(_ range: SummaryPlaybackRange) {
        if range == .week {
            consumeRouteGuidance(.weekSliceReady)
            consumeRouteGuidance(.fiveRecordsNeverPlayed)
        }
    }

    private func refreshTodayPlayback() {
        latestPlayback = playbackService.buildTodayPlayback(from: items)
    }

    private func refreshRouteGuidanceIfNeeded() {
        guard activeRouteGuidance == nil else { return }
        let weekCount: Int
        if let interval = PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: .now) {
            weekCount = items.filter { $0.createdAt >= interval.start && $0.createdAt < interval.end }.count
        } else {
            weekCount = 0
        }
        if weekCount >= 3 && routeQuotaStore.weekRemaining(isMember: false) > 0 {
            emitRouteGuidance(.weekSliceReady)
        } else if items.count >= 5 && !routeQuotaStore.hasCompletedWeekPlaybackEver() {
            emitRouteGuidance(.fiveRecordsNeverPlayed)
        }
    }

    private func emitRouteGuidance(_ guidance: PlaybackRouteGuidance) {
        let key = routeGuidanceHandledKey(for: guidance)
        guard !emittedRouteGuidanceKeys.contains(key) else { return }
        guard !hasHandledRouteGuidance(guidance) else { return }
        activeRouteGuidance = guidance
        emittedRouteGuidanceKeys.insert(key)
        persistRouteGuidanceHandled(guidance)
        analyticsService.track("route_guidance_shown", props: ["type": guidance.rawValue])
    }

    private func hasHandledRouteGuidance(_ guidance: PlaybackRouteGuidance) -> Bool {
        let key = routeGuidanceHandledKey(for: guidance)
        return Set(UserDefaults.standard.stringArray(forKey: Self.routeGuidanceHandledDefaultsKey) ?? []).contains(key)
    }

    private func persistRouteGuidanceHandled(_ guidance: PlaybackRouteGuidance) {
        let key = routeGuidanceHandledKey(for: guidance)
        var handled = Set(UserDefaults.standard.stringArray(forKey: Self.routeGuidanceHandledDefaultsKey) ?? [])
        guard handled.insert(key).inserted else { return }
        UserDefaults.standard.set(Array(handled), forKey: Self.routeGuidanceHandledDefaultsKey)
    }

    private func routeGuidanceHandledKey(for guidance: PlaybackRouteGuidance, date: Date = .now) -> String {
        switch guidance {
        case .firstRecordTodayPlayback:
            return "\(guidance.rawValue):once"
        case .weekSliceReady, .fiveRecordsNeverPlayed:
            let components = PlaybackService.isoCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            let year = components.yearForWeekOfYear ?? 0
            let week = components.weekOfYear ?? 0
            return "\(guidance.rawValue):isoWeek:\(year)-\(week)"
        }
    }

    func regenerateTodayInsight(userName: String, settings: AppSettings) async {
        let key = Self.dayKey(for: .now)
        insights.removeAll { $0.dayKey == key }
        await generateDailyInsight(userName: userName, settings: settings)
    }

    func refreshTodayInsightIfNeeded(userName: String, settings: AppSettings) async {
        await generateDailyInsight(userName: userName, settings: settings)
    }

    nonisolated static func promptTemplate(todayTotal: Double, weeklyAverage: Double, monthlyTotal: Double, topCategories: String) -> String {
        """
        [System]
        你是“叙账”的生活记录整理助手。请根据账本里的真实记录，输出简短回望和一条自然收束或邀请继续记录/下月再看，不说教、不批判、不提供投资买卖建议。
        「议」只谈已经发生的生活：可复述时间、分类、金额和用户写下的具体细节，不替用户解释情绪。
        可以有一点理解和鼓励，但必须贴着真实记录说；像“这一周已经留下几笔可以回看的记录”，不要写成泛泛安慰、心理分析或夸奖。
        禁止：下月/下周金额目标、预算上限、减少支出比例、达成率、任何管控式省钱建议。
        action 字段应像账本页脚的一句自然收束或轻鼓励，不是理财计划，也不是空泛安慰话术。

        [User]
        日期：\(dayKey(for: .now))
        今日总支出：\(todayTotal) 元
        近7日平均日支出：\(weeklyAverage) 元
        本月累计支出：\(monthlyTotal) 元
        TOP分类：\(topCategories)

        请输出 JSON：
        {"summary":"不超过80字","action":"不超过50字","encourage":"不超过30字"}
        """
    }

    func filteredItems(in period: Period) -> [HomeItem] {
        ensureItemDerivedCacheFresh()
        switch period {
        case .week:
            return itemDerivedCache.currentWeekItems
        case .month:
            return itemDerivedCache.currentMonthItems
        }
    }

    func items(in dateInterval: DateInterval) -> [HomeItem] {
        items
            .filter { $0.createdAt >= dateInterval.start && $0.createdAt < dateInterval.end }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func rebuildItemDerivedCache(now: Date = Date()) {
        let calendar = Calendar.current
        let sortedItems = items.sorted { $0.createdAt > $1.createdAt }
        let currentWeekInterval = PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: now)
        let todayPositiveItems = sortedItems.filter {
            calendar.isDate($0.createdAt, inSameDayAs: now) && $0.amount > 0
        }
        let currentWeekItems = sortedItems.filter { item in
            guard let currentWeekInterval else { return false }
            return item.createdAt >= currentWeekInterval.start && item.createdAt < currentWeekInterval.end
        }
        let currentMonthItems = sortedItems.filter {
            calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month)
        }
        let currentYearItems = sortedItems.filter {
            calendar.isDate($0.createdAt, equalTo: now, toGranularity: .year)
        }
        itemDerivedCache = ItemDerivedCache(
            todayPositiveItems: todayPositiveItems,
            recentThreeTodayItems: Array(todayPositiveItems.prefix(3)),
            currentWeekItems: currentWeekItems,
            currentMonthItems: currentMonthItems,
            currentYearItems: currentYearItems
        )
        itemDerivedCacheDayKey = Self.dayKey(for: now)
        itemDerivedCacheNeedsRebuild = false
    }

    private func ensureItemDerivedCacheFresh(now: Date = Date()) {
        guard itemDerivedCacheNeedsRebuild || itemDerivedCacheDayKey != Self.dayKey(for: now) else { return }
        rebuildItemDerivedCache(now: now)
    }

    private func weeklyAverageExpense() -> Double {
        let weeklyItems = filteredItems(in: .week)
        guard !weeklyItems.isEmpty else { return 0 }
        let total = weeklyItems.reduce(0) { $0 + $1.amount }
        return total / 7
    }

    private func resetInput() {
        inputTitle = ""
        inputAmount = ""
        selectedDate = .now
        selectedDateEditedByUser = false
        selectedCategory = .other
        categoryLockedByUser = false
        recordPrefillResult = nil
        recordPrefillAmount = nil
        lastAutoRecommendedCategory = nil
        pendingCategoryCorrectionFrom = nil
    }

    private func persistItems() {
        LocalStore.saveHomeItems(items)
    }

    private func persistInsights() {
        LocalStore.saveDailyInsights(insights)
    }

    private func cloudContext() -> (baseURL: String, accessToken: String)? {
        let settings = LocalStore.loadSettings()
        let baseURL = settings.backendBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = KeychainService.loadAccessToken()
        guard settings.syncEnabled, !baseURL.isEmpty, !token.isEmpty else { return nil }
        return (baseURL, token)
    }

    private func syncUpsertToCloud(_ item: HomeItem) async {
        guard let context = cloudContext() else { return }
        let service = LedgerSyncService(baseURL: context.baseURL, accessToken: context.accessToken)
        do {
            try await service.upload(item)
            syncStatusMessage = "已同步到云端。"
        } catch {
            syncStatusMessage = "这笔记录已保存在本机，云端暂时没同步成功。"
        }
    }

    private func syncDeleteFromCloud(id: UUID) async {
        guard let context = cloudContext() else { return }
        let service = LedgerSyncService(baseURL: context.baseURL, accessToken: context.accessToken)
        do {
            try await service.delete(id: id)
            syncStatusMessage = "云端账单已删除。"
        } catch {
            syncStatusMessage = "本机已更新，云端暂时没同步删除。"
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        value.formatted(.cny.precision(.fractionLength(2)))
    }

    func shortAmountText(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.005 {
            return value.formatted(.cny.precision(.fractionLength(0)))
        }
        return value.formatted(.cny.precision(.fractionLength(2)))
    }

    private func mergeLedgers(local: [HomeItem], remote: [HomeItem]) -> [HomeItem] {
        var map: [UUID: HomeItem] = [:]
        for item in remote {
            map[item.id] = item
        }
        for item in local {
            if let existing = map[item.id] {
                map[item.id] = item.updatedAt >= existing.updatedAt ? item : existing
            } else {
                map[item.id] = item
            }
        }
        return Array(map.values)
    }

    private nonisolated static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func dailyInsightSnapshotSignature(for todayItems: [HomeItem], dayKey: String) -> String {
        let rows = todayItems
            .filter { $0.amount > 0 }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { item in
                [
                    item.id.uuidString,
                    String(format: "%.2f", item.amount),
                    item.category.rawValue,
                    item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    String(Int(item.updatedAt.timeIntervalSince1970))
                ].joined(separator: "#")
            }
        return ([dayKey, "\(rows.count)"] + rows).joined(separator: "|")
    }

    private nonisolated static func monthKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    // MARK: - Insight Actions (matching web insight buttons)

    func setLatestActionCard(_ text: String, scope: String = "none") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !Self.isLowValueActionCardText(trimmed) else { return }
        latestActionCard = ActionCardData(text: trimmed, updatedAt: Date(), scope: scope)
        persistActionCard()
    }

    func buildWeeklyRhythmText() -> String {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -6, to: Date()) else {
            return "这周的记录还不够完整，先继续记几笔。"
        }
        let weekItems = items.filter { $0.createdAt >= start && $0.amount > 0 }
        guard !weekItems.isEmpty else {
            return "这周还没有足够账单，先不用急着复盘。多记几笔后，节奏会更清楚。"
        }
        let top = weekTopCategoryText
        let activeDays = Set(weekItems.map { cal.startOfDay(for: $0.createdAt) }).count
        let rhythm = activeDays >= 5 ? "这周几乎每天都有记录" : "这周的记录主要落在 \(activeDays) 天里"
        if let sceneLine = lifeSceneMemoryLine(from: weekItems, minimumCount: 2) {
            return "\(rhythm)，\(sceneLine)。"
        }
        if top == "暂无" {
            return "\(rhythm)，先把这一周放在这里。"
        }
        return "\(rhythm)，「\(top)」这类记录多一点。先把这一周放在这里。"
    }

    func markWeeklyTag() {
        let weekItems = filteredItems(in: .week).filter { $0.amount > 0 }
        let top = weekTopCategoryText
        let result: String
        if let scene = LifeSceneSemanticService.dominantScene(in: weekItems),
           scene.count >= 2 {
            let theme = LifeSceneSemanticService.displayTheme(for: scene.signal)
            result = "\(LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count))，先把「\(theme)」这条生活线留下。"
        } else {
            result = "这周更常记录到「\(top)」，先把这个生活主题留下。"
        }
        setLatestActionCard(result, scope: "weekly")
        analyticsService.track("weekly_tag_marked", props: ["top": top])
    }

    func buildMonthlyClosingText() -> String {
        let total = monthExpenseTotal
        let top = monthTopCategoryText
        guard total > 0 else {
            return "这个月还没有足够账单，先继续记几笔，月记会更像你的日子。"
        }
        let monthItems = filteredItems(in: .month).filter { $0.amount > 0 }
        if let scene = LifeSceneSemanticService.dominantScene(in: monthItems),
           scene.count >= 2 {
            return "\(LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count))。月末再回看会更完整。"
        }
        return "这个月「\(top)」出现得比较多，先把这条线索留在这里。月末再回看会更完整。"
    }

    func markMonthlyClosing() {
        let result = buildMonthlyClosingText()
        setLatestActionCard(result, scope: "monthly")
        analyticsService.track("monthly_closing_saved")
    }

    func markMonthlySaveSummary() {
        let blocks = localMonthlyInsightBlocks()
        let result = "月度小结：\(blocks.summary)"
        setLatestActionCard(result, scope: "monthly")
        analyticsService.track("monthly_summary_saved")
    }

    func markPlaybackMemoryLine(_ line: String, range: SummaryPlaybackRange) {
        let scope = range == .week ? "weekly" : "monthly"
        setLatestActionCard(line, scope: scope)
        analyticsService.track("playback_memory_line_saved", props: ["range": range.rawValue])
    }

    func regenerateMonthlyInsight() {
        monthlyInsightGenerationCount += 1
    }

    private(set) var monthlyInsightGenerationCount: Int = 0

    private func persistActionCard() {
        guard let card = latestActionCard, let data = try? JSONEncoder().encode(card) else { return }
        UserDefaults.standard.set(data, forKey: "latest_action_card_v1")
    }

    private static func isLowValueActionCardText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let quoted = trimmed
            .replacingOccurrences(of: "这周留下：", with: "")
            .replacingOccurrences(of: "这个月留下：", with: "")
            .replacingOccurrences(of: "这周留下了一笔", with: "")
            .replacingOccurrences(of: "这个月留下了一笔", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "「」『』“”\"' 。."))
        let separators = CharacterSet(charactersIn: "/／、· ")
        let parts = quoted
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return false }
        let lowValueWords = Set(["公交", "地铁", "交通", "餐饮", "吃饭", "早餐", "购物", "日用", "居家", "健康", "放松", "住宿", "出行"])
        return parts.allSatisfy { word in
            lowValueWords.contains(word)
                || HomeItem.Category.allCases.contains(where: { category in
                    category.rawValue == word || category.label == word
                })
        }
    }
}
