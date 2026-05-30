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
    @Published var selectedDate: Date = .now
    @Published var selectedPeriod: Period = .month
    @Published private(set) var ocrStatus: String = ""
    @Published private(set) var isGeneratingInsight: Bool = false
    @Published private(set) var insightErrorMessage: String?
    @Published private(set) var insights: [DailyInsight] = []
    @Published private(set) var items: [HomeItem] = []
    @Published private(set) var syncStatusMessage: String?
    @Published private(set) var isSyncingCloudLedger: Bool = false
    @Published private(set) var memberNudgeCopy: MemberCtaCopy?
    @Published private(set) var activeMemberNudgeScene: MemberFlowScene?
    @Published private(set) var latestPlayback: PlaybackSnapshot?
    @Published private(set) var latestActionCard: ActionCardData?
    @Published var petMessage: String? = nil

    struct ActionCardData: Codable, Equatable {
        var text: String
        var updatedAt: Date
        var scope: String // "weekly", "monthly", "none"
    }

    private let ocrService = OCRService()
    private let aiReportService = AIReportService()
    private let analyticsService = AnalyticsService()
    private let nudgePolicyService = MemberNudgePolicyService()
    private let playbackService = PlaybackService()
    private let memberFlowService = MemberFlowService()

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
    }

    func addManualRecord() {
        guard let amount = Double(inputAmount.replacingOccurrences(of: ",", with: "")), amount > 0 else { return }
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
        // Trigger pet message matching web petCopy.recordSaved
        let msgs = [
            "记下来的每一笔，都是你的掌控感呀！小猫咪为你点赞～",
            "今天也按时记账啦，你超棒的！",
            "这笔记录得很好，继续保持这个节奏～",
            "今天的小快乐，也被好好记下来了。",
        ]
        petMessage = msgs.randomElement()
        Task { await syncUpsertToCloud(newItem) }
    }

    func addOCRDemoRecord() {
        inputTitle = "OCR 识别小票"
        inputAmount = "26.5"
        selectedCategory = .dining
        addManualRecord()
    }

    func prefillFromOCR(imageData: Data) async {
        do {
            let draft = try await ocrService.recognizeReceipt(from: imageData)
            inputTitle = draft.title
            inputAmount = draft.amount > 0 ? String(format: "%.2f", draft.amount) : ""
            selectedCategory = draft.category
            selectedDate = draft.date
            ocrStatus = "识别完成，置信度 \(Int(draft.confidence * 100))%"
        } catch {
            ocrStatus = "识别失败，请重试或手动录入。"
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
            ? "建议对高频支出分类设置分段预算，并在每周末回看预算达成率。"
            : "整体支出节奏可控，继续保持按笔记录，长期会更容易优化消费结构。"
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
            ? "等你有了本月记录，我会帮你梳理分类占比与节奏。"
            : "整体节奏上，\(top) 相关支出占比较高，可以留意是否都在预期内。"
        let advice = total <= 0
            ? "先坚持记一周，复盘会更有感觉。"
            : "下月可以给「\(top)」设一个温柔小预算，不用太紧，轻轻框住就好。"
        return (summary, structure, advice)
    }

    private func topCategoryLabel(in period: Period) -> String {
        let target = filteredItems(in: period)
        let grouped = Dictionary(grouping: target, by: \.category)
        guard let top = grouped.max(by: { $0.value.count < $1.value.count })?.key else {
            return "暂无"
        }
        return top.rawValue
    }

    func recommendCategory(for amountText: String) -> HomeItem.Category? {
        guard let amount = Double(amountText), amount > 0 else { return nil }
        if amount < 30 { return .dining }
        if amount < 80 { return .transport }
        if amount < 200 { return .daily }
        if amount < 600 { return .shopping }
        return .other
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
                    model: settings.aiModel
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
                insightErrorMessage = "远程 AI 不可用，已回退本地建议。"
            }
            }
        }

        let summary = settings.aiTone == .gentle
            ? "\(userName)，今天总支出 \(formatCurrency(todayTotal))，主要花在\(topCategory)。"
            : "今日支出 \(formatCurrency(todayTotal))，高频消费分类：\(topCategory)。"

        let action: String
        if todayTotal > weeklyAverage && weeklyAverage > 0 {
            action = "明天把高频消费先减 1 次，预计会更轻松地控制预算。"
        } else {
            action = "当前节奏很稳，继续保持每笔小额记录就很好。"
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
        syncStatusMessage = "已为你打开会员路径（演示）：请到设置页完成开通。"
    }

    private func refreshTodayPlayback() {
        latestPlayback = playbackService.buildTodayPlayback(from: items)
    }

    func regenerateTodayInsight(userName: String, settings: AppSettings) async {
        let key = Self.dayKey(for: .now)
        insights.removeAll { $0.dayKey == key }
        await generateDailyInsight(userName: userName, settings: settings)
    }

    nonisolated static func promptTemplate(todayTotal: Double, weeklyAverage: Double, monthlyTotal: Double, topCategories: String) -> String {
        """
        [System]
        你是“轻账日记”的温和消费复盘助手。请根据消费聚合数据，输出简短复盘和一条可执行建议，不说教、不批判、不提供投资买卖建议。

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

    // MARK: - Insight Actions (matching web insight buttons)

    func setLatestActionCard(_ text: String, scope: String = "none") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        latestActionCard = ActionCardData(text: trimmed, updatedAt: Date(), scope: scope)
        persistActionCard()
    }

    func buildWeeklyRhythmText() -> String {
        let top = weekTopCategoryText
        return "本周开销以「\(top)」为主，先按当前节奏温柔安排，下周再慢慢微调。"
    }

    func markWeeklyTag() {
        let top = weekTopCategoryText
        let result = "常花类目回看：这周更常记录「\(top)」，后续复盘会更清晰。"
        setLatestActionCard(result, scope: "weekly")
        analyticsService.track("weekly_tag_marked", props: ["top": top])
    }

    func buildMonthlySoftPlanText() -> String {
        let total = monthExpenseTotal
        let next = total > 0 ? String(format: "%.0f", total * 0.95) : "0"
        return "下月生活开销温柔参考：约 ¥\(next)，按你自己的节奏随心调整。"
    }

    func markMonthlySoftPlan() {
        let result = buildMonthlySoftPlanText()
        setLatestActionCard(result, scope: "monthly")
        analyticsService.track("monthly_soft_plan")
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
