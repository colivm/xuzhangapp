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
    @Published var selectedCategory: HomeItem.Category = .dining
    @Published private(set) var categoryLockedByUser: Bool = false
    @Published var selectedDate: Date = .now
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
    @Published var petMessage: String? = nil

    enum PlaybackRouteGuidance: String, Identifiable, Hashable {
        case firstRecordTodayPlayback
        case weekSliceReady
        case fiveRecordsNeverPlayed

        var id: String { rawValue }

        var title: String {
            switch self {
            case .firstRecordTodayPlayback:
                return "用 10 秒叙一下今天"
            case .weekSliceReady:
                return "本周生活切片可播放"
            case .fiveRecordsNeverPlayed:
                return "可以讲这周的故事了"
            }
        }

        var message: String {
            switch self {
            case .firstRecordTodayPlayback:
                return "第一笔已经记好，听一遍今日生活回放。"
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
    private let petCompanionService = PetCompanionService.shared
    private let nudgePolicyService = MemberNudgePolicyService()
    private let playbackService = PlaybackService()
    private let memberFlowService = MemberFlowService()
    private let routeQuotaStore = SummaryPlaybackQuotaStore()
    private let dailyQuotaStore = DailyFeatureQuotaStore()
    private var emittedRouteGuidanceTypes: Set<PlaybackRouteGuidance> = []

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

    func addManualRecord() {
        guard let amount = Double(inputAmount.replacingOccurrences(of: ",", with: "")), amount > 0 else { return }
        let wasEmpty = items.isEmpty
        let trimmed = inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmed.isEmpty ? "\(selectedCategory.rawValue)消费" : trimmed

        let newItem = HomeItem(
            title: title,
            amount: amount,
            category: selectedCategory,
            source: .manual,
            createdAt: selectedDate,
            updatedAt: Date()
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
            ocrStatus = "今日免费识票次数已用完（3/3）。会员可无限智能导入。"
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
            ocrStatus = "今日免费识票次数已用完（3/3）。会员可无限智能导入。"
            return 0
        }

        let now = Date()
        let batchId = UUID().uuidString
        let importedItems = validDrafts.map { draft in
            HomeItem(
                title: draft.title,
                amount: draft.amount,
                category: draft.category,
                source: .ocr,
                createdAt: draft.date,
                updatedAt: now,
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
        ocrStatus = "\(prefix)。今日免费识票剩余 \(remaining)/3 次。"
    }

    func updateOCRDraftStatus(id: UUID, isResolved: Bool) {
        guard let idx = items.firstIndex(where: { $0.id == id }), items[idx].draftMeta != nil else { return }
        items[idx].draftMeta?.status = isResolved ? .resolved : .pending
        items[idx].updatedAt = Date()
        persistItems()
        Task { await syncUpsertToCloud(items[idx]) }
    }

    func updateOCRDraftCategory(id: UUID, category: HomeItem.Category) {
        guard let idx = items.firstIndex(where: { $0.id == id }), items[idx].draftMeta != nil else { return }
        items[idx].category = category
        items[idx].emotionTag = HomeItem.inferEmotionTag(category: category, amount: items[idx].amount)
        items[idx].updatedAt = Date()
        persistItems()
        Task { await syncUpsertToCloud(items[idx]) }
    }

    func updateOCRDraftAmount(id: UUID, amount: Double) {
        guard amount > 0,
              let idx = items.firstIndex(where: { $0.id == id }),
              items[idx].draftMeta != nil else { return }
        items[idx].amount = amount
        items[idx].emotionTag = HomeItem.inferEmotionTag(category: items[idx].category, amount: amount)
        items[idx].updatedAt = Date()
        persistItems()
        Task { await syncUpsertToCloud(items[idx]) }
    }

    func deleteOCRDraftItem(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }), items[idx].draftMeta != nil else { return }
        items.remove(at: idx)
        persistItems()
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
        guard !changedItems.isEmpty else { return }
        persistItems()
        analyticsService.track("ocr_drafts_resolved", props: ["count": String(changedItems.count)])
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
        items[idx] = updated
        persistItems()
        analyticsService.track("record_updated", props: [
            "category": updated.category.rawValue,
            "amount": String(format: "%.2f", updated.amount)
        ])
        refreshTodayPlayback()
        Task { await syncUpsertToCloud(updated) }
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
        let tier = LocalStore.loadSettings().memberTier.lowercased()
        return ["monthly", "yearly", "lifetime"].contains(tier)
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
        return "叙账用户，今天总支出 \(formatCurrency(total))，主要花在\(topCategory)。继续保持每笔小额记录就很好。"
    }

    var weekExpenseTotal: Double {
        let weekItems = filteredItems(in: .week).filter { $0.amount > 0 }
        return weekItems.reduce(0) { $0 + $1.amount }
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
        let total = weekItems.reduce(0) { $0 + $1.amount }
        let catMap = Dictionary(grouping: weekItems, by: \.category).mapValues { cats in
            cats.reduce(0) { $0 + $1.amount }
        }
        let top = catMap.max(by: { $0.value < $1.value })
        let topCategory = top?.key.rawValue ?? "暂无"
        let topAmount = top?.value ?? 0
        let ratio = total > 0 ? Int(round(topAmount / total * 100)) : 0

        let summary = "近7天总支出 \(formatCurrency(total))，主要集中在\(topCategory)。"
        let structure = "近7天共记录 \(weekItems.count) 笔，\(topCategory)占比约 \(ratio)%。"
        let advice = total > 3000
            ? "这一周的记录已经很有轮廓，继续按笔记下去，下周生活切片会更像你的真实日常。"
            : "这一周的节奏被慢慢记下来了，继续记录，下周生活章会更立体。"
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
            summary = "本月累计支出 \(formatCurrency(total))，消费里「\(top)」出现得比较多。"
        }
        let structure = total <= 0
            ? "等你有了本月记录，我会帮你梳理分类占比与生活节奏。"
            : "「\(top)」是这个月比较明显的一块生活拼图。"
        let advice = total <= 0
            ? "先坚持记一周，复盘会更有感觉。"
            : "这个月的轮廓已经出来了，继续记录几天，月末生活章会更完整。"
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
        let start = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
        let recentItems = items.filter { $0.createdAt >= start && $0.amount > 0 }
        return categoryRecommendService.recommend(
            input: CategoryRecommendInput(
                amount: amount,
                referenceDate: selectedDate,
                items: recentItems,
                noteDraft: inputTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                locked: categoryLockedByUser
            )
        )
    }

    func selectCategory(_ category: HomeItem.Category) {
        selectedCategory = category
        categoryLockedByUser = true
    }

    func applyRecommendedCategory(_ category: HomeItem.Category) {
        guard !categoryLockedByUser else { return }
        selectedCategory = category
    }

    func noteSuggestions(for category: HomeItem.Category) -> [String] {
        switch category {
        case .dining:
            return ["午餐简餐", "咖啡/奶茶", "晚餐聚餐"]
        case .shopping:
            return ["日常补货", "冲动消费", "电商下单"]
        case .transport:
            return ["地铁通勤", "打车出行", "停车/油费"]
        case .entertainment:
            return ["电影娱乐", "游戏充值", "周末放松"]
        case .daily:
            return ["家用日化", "药店采购", "生活用品"]
        case .lodging:
            return ["酒店住宿", "差旅住宿", "民宿短住"]
        case .other:
            return ["杂项开支", "临时支出", "待分类记录"]
        }
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
            ? "\(userName)，今天总支出 \(formatCurrency(todayTotal))，主要花在\(topCategory)。"
            : "今日支出 \(formatCurrency(todayTotal))，高频消费分类：\(topCategory)。"

        let action: String
        if todayTotal > weeklyAverage && weeklyAverage > 0 {
            action = "今天的花费比平时多一些，先把这一笔生活节奏记下来就好。"
        } else {
            action = "当前节奏被好好记下来了，明天继续顺手记一两笔就好。"
        }

        let encourage = settings.aiTone == .gentle
            ? "慢慢来，你已经在把钱花得更明白了。"
            : "持续记录，你会更快看到变化。"

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
        let tier = LocalStore.loadSettings().memberTier.lowercased()
        let isPaid = ["monthly", "yearly", "lifetime"].contains(tier)
        guard !isPaid else {
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
        guard let activeRouteGuidance else { return }
        if let guidance, guidance != activeRouteGuidance { return }
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
        let weekCount = items.filter {
            Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .weekOfYear)
        }.count
        if weekCount >= 3 && routeQuotaStore.weekRemaining(isMember: false) > 0 {
            emitRouteGuidance(.weekSliceReady)
        } else if items.count >= 5 && !routeQuotaStore.hasCompletedWeekPlaybackEver() {
            emitRouteGuidance(.fiveRecordsNeverPlayed)
        }
    }

    private func emitRouteGuidance(_ guidance: PlaybackRouteGuidance) {
        guard !emittedRouteGuidanceTypes.contains(guidance) else { return }
        activeRouteGuidance = guidance
        emittedRouteGuidanceTypes.insert(guidance)
        analyticsService.track("route_guidance_shown", props: ["type": guidance.rawValue])
    }

    func regenerateTodayInsight(userName: String, settings: AppSettings) async {
        let key = Self.dayKey(for: .now)
        insights.removeAll { $0.dayKey == key }
        await generateDailyInsight(userName: userName, settings: settings)
    }

    nonisolated static func promptTemplate(todayTotal: Double, weeklyAverage: Double, monthlyTotal: Double, topCategories: String) -> String {
        """
        [System]
        你是“叙账”的温和消费复盘助手。请根据消费聚合数据，输出简短复盘和一条温柔收束或邀请继续记录/下月再叙，不说教、不批判、不提供投资买卖建议。
        「议」只谈已经发生的生活：可复述结构、节奏与感受。
        禁止：下月/下周金额目标、预算上限、减少支出比例、达成率、任何管控式省钱建议。
        action 字段应是温柔收束或邀请继续记录/下月再叙，不是理财计划。

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
                return calendar.isDate(item.createdAt, equalTo: .now, toGranularity: .weekOfYear)
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
        selectedCategory = .dining
        categoryLockedByUser = false
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
        let top = weekTopCategoryText
        return "本周开销以「\(top)」为主，这一段的节奏就是这样，记下来了。"
    }

    func markWeeklyTag() {
        let top = weekTopCategoryText
        let result = "常花类目回看：这周更常记录「\(top)」，后续复盘会更清晰。"
        setLatestActionCard(result, scope: "weekly")
        analyticsService.track("weekly_tag_marked", props: ["top": top])
    }

    func buildMonthlyClosingText() -> String {
        let total = monthExpenseTotal
        let top = monthTopCategoryText
        guard total > 0 else {
            return "这个月还没有足够账单，先继续记几笔，月末生活章会更像你的日子。"
        }
        return "这个月「\(top)」出现得比较多，有几笔像是对自己的照顾。先记到这里，月末再回看会更完整。"
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
