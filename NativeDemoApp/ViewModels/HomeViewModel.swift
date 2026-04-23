import Foundation

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

    private let ocrService = OCRService()
    private let aiReportService = AIReportService()

    init() {
        items = LocalStore.loadHomeItems().sorted { $0.createdAt > $1.createdAt }
        insights = LocalStore.loadDailyInsights().sorted { $0.createdAt > $1.createdAt }
    }

    func addManualRecord() {
        let trimmed = inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            let amount = Double(inputAmount),
            amount > 0
        else { return }

        let newItem = HomeItem(
            title: trimmed,
            amount: amount,
            category: selectedCategory,
            source: .manual,
            createdAt: selectedDate
        )
        items.insert(newItem, at: 0)
        resetInput()
        persistItems()
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
        items.remove(atOffsets: offsets)
        persistItems()
    }

    var monthExpenseTotal: Double {
        let monthItems = filteredItems(in: .month)
        return monthItems.reduce(0) { $0 + $1.amount }
    }

    var recentThreeItems: [HomeItem] {
        Array(items.prefix(3))
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
        isGeneratingInsight = false
    }

    func regenerateTodayInsight(userName: String, settings: AppSettings) async {
        let key = Self.dayKey(for: .now)
        insights.removeAll { $0.dayKey == key }
        await generateDailyInsight(userName: userName, settings: settings)
    }

    static func promptTemplate(todayTotal: Double, weeklyAverage: Double, monthlyTotal: Double, topCategories: String) -> String {
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

    private func formatCurrency(_ value: Double) -> String {
        value.formatted(.currency(code: "CNY").precision(.fractionLength(2)))
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
