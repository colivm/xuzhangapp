import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    enum Period: String, CaseIterable, Identifiable {
        case week = "本周"
        case month = "本月"

        var id: String { rawValue }
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
    @Published private(set) var items: [HomeItem] = []
    @Published private(set) var syncStatusMessage: String?
    @Published private(set) var isSyncingCloudLedger: Bool = false
    @Published private(set) var memberNudgeCopy: MemberCtaCopy?
    @Published private(set) var activeMemberNudgeScene: MemberFlowScene?
    @Published private(set) var latestPlayback: PlaybackSnapshot?
    @Published private(set) var latestActionCard: ActionCardData?
    @Published private(set) var activeRouteGuidance: PlaybackRouteGuidance?
    @Published private(set) var recordPrefillResult: RecordPrefillResult?
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

    init() {
        items = LocalStore.loadHomeItems().sorted { $0.createdAt > $1.createdAt }
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
            if !expired { latestActionCard = card }
        }
        analyticsService.track("app_open", props: ["items": String(items.count)])
        refreshTodayPlayback()
        refreshRouteGuidanceIfNeeded()
    }

    func addManualRecord(userEditedTitle: Bool = false) {
        guard let amount = Double(inputAmount.replacingOccurrences(of: ",", with: "")), amount > 0 else { return }
        let wasEmpty = items.isEmpty
        let trimmed = inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseTitle = trimmed.isEmpty ? selectedCategory.defaultRecordTitle : trimmed
        let brand = MerchantBrandCatalog.matchBrand(in: baseTitle)
        let category = NarrativeCopyResolver.resolveCategory(brandId: brand?.id, fallback: selectedCategory)
        let title = NarrativeCopyResolver.resolveTitle(brandId: brand?.id, fallback: baseTitle)
        let emotionTag = resolvedEmotionTag(
            brandId: brand?.id,
            category: category,
            amount: amount,
            date: selectedDate,
            seed: title,
            note: title
        )

        let newItem = HomeItem(
            title: title,
            amount: amount,
            category: category,
            source: .manual,
            createdAt: selectedDate,
            updatedAt: Date(),
            emotionTag: emotionTag,
            merchantBrandId: brand?.id,
            userEditedTitle: userEditedTitle ? true : nil
        )
        items.insert(newItem, at: 0)
        resetInput()
        persistItems()
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
            ocrStatus = "今日免费账单识别次数已用完（3/3）。会员可无限智能导入。"
            return []
        }
        do {
            let drafts = try await ocrService.recognizeReceipt(from: imageData)
            let count = drafts.count
            let total = drafts.reduce(0) { $0 + $1.amount }
            ocrStatus = "识别到 \(count) 条，合计 \(formatCurrency(total))。请确认后导入。"
            return drafts
        } catch {
            ocrStatus = (error as? LocalizedError)?.errorDescription ?? "识别失败，请重试或手动录入。"
            return []
        }
    }

    func importOCRDrafts(_ drafts: [OCRReceiptDraft], isMember: Bool) -> Int {
        let validDrafts = drafts.filter { $0.amount > 0 }
        guard !validDrafts.isEmpty else {
            ocrStatus = "未选择可导入的账单。"
            return 0
        }
        guard dailyQuotaStore.canUseOCR(isMember: isMember) else {
            ocrStatus = "今日免费账单识别次数已用完（3/3）。会员可无限智能导入。"
            return 0
        }

        let now = Date()
        let batchId = UUID().uuidString
        let importedItems = validDrafts.map { draft in
            let category = NarrativeCopyResolver.resolveCategory(brandId: draft.merchantBrandId, fallback: draft.category)
            let title = NarrativeCopyResolver.resolveTitle(brandId: draft.merchantBrandId, fallback: draft.title)
            return HomeItem(
                title: title,
                amount: draft.amount,
                category: category,
                source: .ocr,
                createdAt: draft.date,
                updatedAt: now,
                emotionTag: resolvedEmotionTag(
                    brandId: draft.merchantBrandId,
                    category: category,
                    amount: draft.amount,
                    date: draft.date,
                    seed: "\(draft.id.uuidString)|\(title)",
                    note: title
                ),
                merchantBrandId: draft.merchantBrandId,
                draftMeta: HomeItem.DraftMeta(
                    batchId: batchId,
                    importedAt: now,
                    status: .pending
                )
            )
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
        updateOCRSuccessStatus(prefix: "已导入 \(importedItems.count) 条，进入待整理", isMember: isMember)
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
        guard !isMember else {
            ocrStatus = "\(prefix)。会员 OCR 不限次。"
            return
        }
        let remaining = dailyQuotaStore.ocrRemaining(isMember: false)
            ocrStatus = "\(prefix)。今日免费账单识别剩余 \(remaining)/3 次。"
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

    private func resolvedEmotionTag(
        brandId: String?,
        category: HomeItem.Category,
        amount: Double,
        date: Date,
        seed: String,
        note: String = ""
    ) -> String {
        NarrativeCopyResolver.resolveEmotionTag(
            context: NarrativeCopyResolver.Context(
                brandId: brandId,
                category: category,
                amount: amount,
                date: date,
                seed: seed,
                note: note
            )
        )
    }

    func updateOCRDraftCategory(id: UUID, category: HomeItem.Category) {
        guard let idx = items.firstIndex(where: { $0.id == id }), items[idx].draftMeta != nil else { return }
        let resolvedCategory = NarrativeCopyResolver.resolveCategory(brandId: items[idx].merchantBrandId, fallback: category)
        items[idx].category = resolvedCategory
        items[idx].emotionTag = resolvedEmotionTag(
            brandId: items[idx].merchantBrandId,
            category: resolvedCategory,
            amount: items[idx].amount,
            date: items[idx].createdAt,
            seed: "\(items[idx].id.uuidString)|\(items[idx].title)",
            note: items[idx].title
        )
        items[idx].updatedAt = Date()
        persistItems()
        Task { await syncUpsertToCloud(items[idx]) }
    }

    func updateOCRDraftAmount(id: UUID, amount: Double) {
        guard amount > 0,
              let idx = items.firstIndex(where: { $0.id == id }),
              items[idx].draftMeta != nil else { return }
        items[idx].amount = amount
        items[idx].emotionTag = resolvedEmotionTag(
            brandId: items[idx].merchantBrandId,
            category: items[idx].category,
            amount: amount,
            date: items[idx].createdAt,
            seed: "\(items[idx].id.uuidString)|\(items[idx].title)",
            note: items[idx].title
        )
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

    func updateItem(_ updated: HomeItem) {
        guard let idx = items.firstIndex(where: { $0.id == updated.id }) else { return }
        let original = items[idx]
        var resolved = updated
        let matchedBrand = MerchantBrandCatalog.matchBrand(in: updated.title)
        let brandId = matchedBrand?.id ?? updated.merchantBrandId
        resolved.merchantBrandId = brandId
        resolved.category = NarrativeCopyResolver.resolveCategory(brandId: brandId, fallback: updated.category)
        resolved.title = NarrativeCopyResolver.resolveTitle(brandId: brandId, fallback: updated.title)
        resolved.emotionTag = resolvedEmotionTag(
            brandId: brandId,
            category: resolved.category,
            amount: resolved.amount,
            date: resolved.createdAt,
            seed: "\(resolved.id.uuidString)|\(resolved.title)",
            note: resolved.title
        )
        let titleWasEdited = updated.title.trimmingCharacters(in: .whitespacesAndNewlines)
            != original.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if resolved.userEditedTitle == true || titleWasEdited {
            resolved.userEditedTitle = true
        }
        items[idx] = resolved
        persistItems()
        analyticsService.track("record_updated", props: [
            "category": resolved.category.rawValue,
            "amount": String(format: "%.2f", resolved.amount)
        ])
        refreshTodayPlayback()
        Task { await syncUpsertToCloud(resolved) }
    }

    func syncCloudLedgerNow() async {
        let context = cloudContext()
        guard let context else {
            syncStatusMessage = "未登录云端，已跳过同步。"
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
            syncStatusMessage = "云端账单已同步。"
        } catch {
            syncStatusMessage = error.localizedDescription
        }
    }

    var hasMemberAccess: Bool {
        AppSettings.hasMemberAccess(tier: LocalStore.loadSettings().memberTier)
    }

    var monthExpenseTotal: Double {
        let monthItems = filteredItems(in: .month).filter { $0.amount > 0 }
        return monthItems.reduce(0) { $0 + $1.amount }
    }

    var todayExpenseTotal: Double {
        let todayItems = items.filter { Calendar.current.isDateInToday($0.createdAt) && $0.amount > 0 }
        return todayItems.reduce(0) { $0 + $1.amount }
    }

    var todayHeroSubtitle: String {
        let todayItems = items.filter { Calendar.current.isDateInToday($0.createdAt) && $0.amount > 0 }
        let total = todayItems.reduce(0) { $0 + $1.amount }
        let topCategory = todayItems
            .reduce(into: [HomeItem.Category: Double]()) { result, item in
                result[item.category, default: 0] += item.amount
            }
            .max(by: { $0.value < $1.value })?.key.rawValue ?? "无"
        guard total > 0 else {
            return "今天还没记支出，先从一笔小额开始就很好。"
        }
        return "今天的记录里，「\(topCategory)」最常出现，日子又多了一点细节。"
    }

    var weekExpenseTotal: Double {
        let weekItems = filteredItems(in: .week).filter { $0.amount > 0 }
        return weekItems.reduce(0) { $0 + $1.amount }
    }

    var todayStoryNarrative: TodayStoryNarrative {
        let records = todayItems
        let count = records.count
        let totalText = todayExpenseTotal.formatted(.cny)
        let weekText = weekExpenseTotal.formatted(.cny)
        let topCategory = topCategoryLabel(from: records)

        let title: String
        let subtitle: String
        switch count {
        case 0:
            title = "今天先记下来"
            subtitle = "晚上再回头看，这一天会更清楚。"
        case 1:
            title = "今天的第一笔记录"
            let emotion = records.first?.emotionTag.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            subtitle = "\(!emotion.isEmpty ? emotion : "这笔生活被记下来了")，这一天刚翻开第一页。"
        case 2:
            title = "今天已记下 2 笔"
            subtitle = "主要在「\(topCategory)」上，记录变得具体。"
        case 3:
            title = "今天记下了 3 笔"
            subtitle = "合计 \(totalText)，今天的记录已经成形。"
        default:
            title = "今天记下了 \(count) 笔"
            subtitle = "「\(topCategory)」居多，今天的记录已经清楚。"
        }

        return TodayStoryNarrative(
            title: title,
            subtitle: subtitle,
            todayTotalText: "今日合计 \(totalText)",
            weekTotalText: "本周累计 \(weekText)"
        )
    }

    var monthTopCategoryText: String {
        topCategoryLabel(in: .month)
    }

    var weekTopCategoryText: String {
        topCategoryLabel(in: .week)
    }

    /// 近 7 日内生成的复盘记录（按时间新到旧）。
    var insightsLast7Days: [DailyInsight] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -7, to: Date()) else { return [] }
        return insights
            .filter { $0.createdAt >= start }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 本地 7 天聚合复盘（与 web rangeInsightPayload(7) 对齐：一条总结而非逐日）。
    func localWeeklyInsightBlocks() -> (summary: String, structure: String, advice: String) {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -6, to: Date()) else {
            return ("近 7 天暂无复盘。", "", "")
        }
        let weekItems = items.filter { $0.createdAt >= start && $0.amount > 0 }
        guard !weekItems.isEmpty else {
            return ("近 7 天暂无复盘。多记几笔，就能看到更完整的消费节奏啦。", "", "")
        }
        let catMap = Dictionary(grouping: weekItems, by: \.category).mapValues { cats in
            cats.reduce(0) { $0 + $1.amount }
        }
        let top = catMap.max(by: { $0.value < $1.value })
        let topCategory = top?.key.rawValue ?? "暂无"

        let summary = "近 7 天里，\(topCategory)出现得多一些。"
        let structure = "这一周的记录已经分出几段。"
        let advice = weekItems.count >= 8
            ? "继续按笔记下去，下周回放会更贴近真实记录。"
            : "再多记几笔，这一周会更容易回头看。"
        return (summary, structure, advice)
    }

    /// 本地月度小结文案（与 web 预览结构对齐：摘要 / 结构 / 建议）。
    func localMonthlyInsightBlocks() -> (summary: String, structure: String, advice: String) {
        let total = monthExpenseTotal
        let top = monthTopCategoryText
        let summary: String
        if total <= 0 {
            summary = "本月还没有足够账单，多记几笔再来生成月度复盘吧。"
        } else {
            summary = "这个月的记录里，「\(top)」出现得比较多。"
        }
        let structure = total <= 0
            ? "等本月多几笔记录，再整理这段时间的变化。"
            : "「\(top)」是这个月比较明显的一类。"
        let advice = total <= 0
            ? "先记下一周，复盘会更有内容。"
            : "这个月已经有一些记录，继续记几天，月记会更完整。"
        return (summary, structure, advice)
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
                    insightErrorMessage = error.localizedDescription
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

    private func topCategoryLabel(in period: Period) -> String {
        let target = filteredItems(in: period)
        let grouped = Dictionary(grouping: target, by: \.category)
        guard let top = grouped.max(by: { $0.value.count < $1.value.count })?.key else {
            return "暂无"
        }
        return top.rawValue
    }

    private func topCategoryLabel(from target: [HomeItem]) -> String {
        let grouped = Dictionary(grouping: target, by: \.category)
        guard let top = grouped.max(by: { lhs, rhs in
            let left = lhs.value.reduce(0) { $0 + $1.amount }
            let right = rhs.value.reduce(0) { $0 + $1.amount }
            return left < right
        })?.key else {
            return "生活"
        }
        return top.label
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
        if let category = recordPrefillResult?.category,
           let recordPrefillAmount,
           abs(recordPrefillAmount - amount) < 0.005 {
            return CategoryRecommendResult(recommended: category, reasonTag: recordPrefillResult?.source)
        }
        let trimmedNote = inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let brand = MerchantBrandCatalog.matchBrand(in: trimmedNote), !categoryLockedByUser {
            return CategoryRecommendResult(recommended: brand.category, reasonTag: "brand")
        }
        let start = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
        let recentItems = items.filter { $0.createdAt >= start && $0.amount > 0 }
        return categoryRecommendService.recommend(
            input: CategoryRecommendInput(
                amount: amount,
                referenceDate: selectedDate,
                items: recentItems,
                noteDraft: inputTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                locked: categoryLockedByUser,
                context: currentRecordContextSignal()
            )
        )
    }

    private func currentRecordContextSignal() -> RecordContextSignal {
        let settings = LocalStore.loadSettings()
        // Coarse local context only: cached weather plus time bands, no location trail or POI.
        let weather = settings.weatherCompanionEnabled ? WeatherCompanionService.shared.cachedSnapshot : nil
        return RecordContextSignal(referenceDate: selectedDate, weather: weather)
    }

    func refreshRecordPrefill(applySuggestedTitle: Bool = true) {
        let normalizedAmount = inputAmount.replacingOccurrences(of: ",", with: "")
        guard let amount = Double(normalizedAmount), amount > 0 else {
            recordPrefillResult = nil
            recordPrefillAmount = nil
            return
        }

        let trimmedNote = inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = MerchantBrandCatalog.matchBrand(in: trimmedNote)
        if let brand, !categoryLockedByUser {
            applyRecommendedCategory(brand.category)
        }

        let start = Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? .distantPast
        let recentItems = items.filter { $0.createdAt >= start && $0.amount > 0 }
        let result = recordPrefillService.prefill(
            input: RecordPrefillInput(
                amount: amount,
                referenceDate: selectedDate,
                items: recentItems,
                noteDraft: trimmedNote,
                categoryLocked: categoryLockedByUser,
                merchantBrandId: brand?.id,
                context: currentRecordContextSignal()
            )
        )
        recordPrefillResult = result
        recordPrefillAmount = amount

        guard let result else { return }
        if let category = result.category, result.confidence >= 0.55 {
            applyRecommendedCategory(category)
        }
        if applySuggestedTitle, let title = result.title, result.confidence >= 0.65, trimmedNote.isEmpty {
            inputTitle = title
        }
    }

    func selectCategory(_ category: HomeItem.Category) {
        selectedCategory = category
        categoryLockedByUser = true
    }

    func applyRecommendedCategory(_ category: HomeItem.Category) {
        guard !categoryLockedByUser else { return }
        selectedCategory = category
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
        switch category {
        case .dining:
            let hour = Calendar.current.component(.hour, from: date)
            switch hour {
            case 5..<10:
                return ["早餐路上买点吃的", "早班前续一杯咖啡", "出门前吃一口热的"]
            case 10..<14:
                return ["午间简单吃一顿", "食堂一份热饭", "饭点买杯喝的"]
            case 14..<17:
                return ["下午续一杯咖啡", "便利店买点轻食", "忙到一半补一口"]
            case 17..<21:
                return ["晚餐吃一顿热饭", "下班后吃点热乎的", "和人一起吃晚饭"]
            default:
                return ["加班后吃点热乎的", "晚归路上的一口热食", "深夜买点小食"]
            }
        case .transport:
            return ["地铁到站，今天也准时出门", "打车赶去这一段", "停车和油费记一笔"]
        case .shopping:
            return ["下单一个需要的", "买到常用的小东西", "快递路上记一笔"]
        case .daily:
            return ["便利店补一袋日常", "超市买点家里要用的", "日用品刚好补上"]
        case .entertainment:
            return ["买了这场电影票", "游戏里充了一笔", "周末出去坐一会儿"]
        case .lodging:
            return ["今晚住在这里", "出差住宿记一笔", "短住一晚记下"]
        case .health:
            return ["药店买点常用药", "挂号问诊记一笔", "体检护理记一笔"]
        case .home:
            return ["水电燃气交上了", "家里添个要用的", "修修补补记一笔"]
        case .social:
            return ["见面带点东西", "和朋友吃了一顿", "探望时买点东西"]
        case .other:
            return ["临时花了一笔", "还没想好归哪类", "先把这笔记下"]
        }
    }

    func frequentRecordAmounts(at date: Date = .now) -> [Double] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -180, to: date) ?? .distantPast
        let recentItems = items.filter { item in
            item.amount > 0 && item.createdAt >= start && item.createdAt <= date
        }
        guard recentItems.count >= 15 else { return [] }

        let targetBucket = hourHabitBucket(for: date)
        let targetWeekend = isHabitWeekend(date)
        let contextItems = recentItems.filter { item in
            hourHabitBucket(for: item.createdAt) == targetBucket &&
            isHabitWeekend(item.createdAt) == targetWeekend
        }
        guard contextItems.count >= 5 else { return [] }

        let grouped = Dictionary(grouping: contextItems) { item in
            Int((item.amount * 100).rounded())
        }
        return grouped
            .map { entry in
                let cents = entry.key
                let group = entry.value
                (
                    amount: Double(cents) / 100,
                    count: group.count,
                    latest: group.map(\.createdAt).max() ?? .distantPast
                )
            }
            .filter { candidate in
                candidate.count >= 3 &&
                candidate.amount > 0 &&
                candidate.amount <= 9999
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.latest > rhs.latest
                }
                return lhs.count > rhs.count
            }
            .prefix(3)
            .map(\.amount)
    }

    private func hourHabitBucket(for date: Date) -> Int {
        Calendar.current.component(.hour, from: date) / 3
    }

    private func isHabitWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    var todayItems: [HomeItem] {
        items.filter { Calendar.current.isDateInToday($0.createdAt) && $0.amount > 0 }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var recentThreeItems: [HomeItem] {
        Array(todayItems.prefix(3))
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
        if insights.contains(where: { $0.dayKey == key }) {
            return
        }

        isGeneratingInsight = true
        insightErrorMessage = nil

        let todayItems = items.filter { Calendar.current.isDateInToday($0.createdAt) }
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
                    encourage: payload.encourage
                )
                insights.insert(remoteInsight, at: 0)
                persistInsights()
                _ = AIUsageLimiter.consumeOnce(limitPerMonth: settings.remoteAIMonthlyLimit)
                analyticsService.track("ai_daily_generated", props: ["mode": "live", "items": String(todayItems.count)])
                isGeneratingInsight = false
                return
            } catch {
                insightErrorMessage = "远程 AI 不可用，已回退本地建议。\(error.localizedDescription)"
            }
            }
        }

        let summary = settings.aiTone == .gentle
            ? "\(userName)，今天的记录里「\(topCategory)」最常出现。"
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
            encourage: encourage
        )
        insights.insert(insight, at: 0)
        persistInsights()
        analyticsService.track("ai_daily_generated", props: ["mode": "local_fallback", "items": String(todayItems.count)])
        isGeneratingInsight = false
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
        guard !AppSettings.hasMemberAccess(tier: LocalStore.loadSettings().memberTier) else {
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

    private func filteredItems(in period: Period) -> [HomeItem] {
        let calendar = Calendar.current
        return items.filter { item in
            switch period {
            case .week:
                guard let interval = PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: .now) else { return false }
                return item.createdAt >= interval.start && item.createdAt < interval.end
            case .month:
                return calendar.isDate(item.createdAt, equalTo: .now, toGranularity: .month)
            }
        }
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
        guard !baseURL.isEmpty, !token.isEmpty else { return nil }
        return (baseURL, token)
    }

    private func syncUpsertToCloud(_ item: HomeItem) async {
        guard let context = cloudContext() else { return }
        let service = LedgerSyncService(baseURL: context.baseURL, accessToken: context.accessToken)
        do {
            try await service.upload(item)
            syncStatusMessage = "已同步到云端。"
        } catch {
            syncStatusMessage = error.localizedDescription
        }
    }

    private func syncDeleteFromCloud(id: UUID) async {
        guard let context = cloudContext() else { return }
        let service = LedgerSyncService(baseURL: context.baseURL, accessToken: context.accessToken)
        do {
            try await service.delete(id: id)
            syncStatusMessage = "云端账单已删除。"
        } catch {
            syncStatusMessage = error.localizedDescription
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        value.formatted(.cny.precision(.fractionLength(2)))
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

    private nonisolated static func monthKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    // MARK: - Insight Actions (matching web insight buttons)

    func setLatestActionCard(_ text: String, scope: String = "none") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
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
        let total = weekItems.reduce(0) { $0 + $1.amount }
        let activeDays = Set(weekItems.map { cal.startOfDay(for: $0.createdAt) }).count
        let rhythm = activeDays >= 5 ? "记录分布得比较均匀" : "记录集中在 \(activeDays) 天里"
        return "这周共 \(weekItems.count) 笔，合计 \(total.formatted(.cny))，\(rhythm)。 「\(top)」是最显眼的一段，这一周已经有了可回看的记录。"
    }

    func markWeeklyTag() {
        let top = weekTopCategoryText
        let result = "这周更常记录到「\(top)」，先把这个生活主题留下。"
        setLatestActionCard(result, scope: "weekly")
        analyticsService.track("weekly_tag_marked", props: ["top": top])
    }

    func buildMonthlyClosingText() -> String {
        let total = monthExpenseTotal
        let top = monthTopCategoryText
        guard total > 0 else {
            return "这个月还没有足够账单，先继续记几笔，月记会更像你的日子。"
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

    func regenerateMonthlyInsight() {
        monthlyInsightGenerationCount += 1
    }

    private(set) var monthlyInsightGenerationCount: Int = 0

    private func persistActionCard() {
        guard let card = latestActionCard, let data = try? JSONEncoder().encode(card) else { return }
        UserDefaults.standard.set(data, forKey: "latest_action_card_v1")
    }
}
