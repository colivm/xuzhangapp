import SwiftUI
import UIKit

// MARK: - Insight View

struct InsightWebView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    var onNavigateSettings: (() -> Void)? = nil
    var onShowMemberPricing: (() -> Void)? = nil
    @State private var monthlyInsightGenerated = false
    @State private var showAdvancedInsight = false
    @State private var monthlyTrialUsed = UserDefaults.standard.integer(forKey: "monthly_trial_used_v1")
    @State private var monthlyReport: HomeViewModel.MonthlyInsightReport?
    @State private var monthlyAIStatus: AIStatusPill?
    @State private var monthlyTrialModal: MonthlyTrialModal?
    @State private var isSavingWeeklyShareCard = false
    @State private var weeklyShareSaveMessage: String?
    @State private var isTodayInsightExpanded = false
    @State private var showMonthlyInsightSheet = false
    @State private var showTodayInsightSheet = false
    @State private var monthlyActionMessage: String?
    @State private var monthlyNarrativeVariant = 0
    @State private var showWeeklySharePrivacyConfirm = false
    private let trialTotal = 5

    private struct AIStatusPill: Equatable {
        enum Kind {
            case live
            case fallback
            case error
        }

        var kind: Kind
        var text: String
    }

    private struct MonthlyTrialModal: Identifiable {
        let id = UUID()
        var title: String
        var body: String
    }

    private var hasMemberAccess: Bool {
        settingsViewModel.settings.hasMemberAccess
    }

    var body: some View {
        ZStack {
            ScrollView {
                insightContent
            }
            .scrollIndicators(.hidden)

            if let modal = monthlyTrialModal {
                monthlyTrialOverlay(modal)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if showWeeklySharePrivacyConfirm {
                weeklySharePrivacyOverlay
                    .transition(.opacity)
                    .zIndex(30)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: monthlyTrialModal?.id)
        .animation(.easeInOut(duration: 0.2), value: showWeeklySharePrivacyConfirm)
        .sheet(isPresented: $showMonthlyInsightSheet) {
            monthlyInsightSheet
        }
        .sheet(isPresented: $showTodayInsightSheet) {
            todayInsightSheet
        }
    }

    private var insightContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            insightJournalCard
            insightChapterFootnote
            keywordBubbleSection
                .padding(.top, -2)
                .padding(.bottom, 12)
            insightNextChapter
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 120)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var insightJournalCard: some View {
        let weeklyBlocks = homeViewModel.localWeeklyInsightBlocks()
        return VStack(alignment: .leading, spacing: 13) {
            Text(weekKickerText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.subtext.opacity(0.78))

            Text(formatWeeklyJournalText(weeklyBlocks))
                .font(.system(size: 17, weight: .medium))
                .lineSpacing(6)
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(weeklyJournalClosing(weeklyBlocks))
                .font(.system(size: 13))
                .italic()
                .foregroundStyle(AppColors.subtext.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            Text(homeViewModel.buildWeeklyRhythmText())
                .font(.system(size: 13))
                .lineSpacing(4)
                .foregroundStyle(AppColors.text.opacity(0.78))
                .padding(.top, 2)

            quietTextButton("保存周记摘页") {
                showWeeklySharePrivacyConfirm = true
            }
            .padding(.top, 2)

            if let weeklyShareSaveMessage {
                Text(weeklyShareSaveMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
            }
        }
        .padding(.leading, 4)
        .paperChapterPanel(radius: 22, padding: 20)
    }

    private var insightChapterFootnote: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(AppColors.accent.opacity(0.20))
                .frame(width: 2, height: 30)
            Text("这一章先翻到这里，下面只挑几枚有记录支撑的小词。")
                .font(.system(size: 13))
                .italic()
                .foregroundStyle(AppColors.subtext.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 24)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var keywordBubbleSection: some View {
        let keywords = monthlyKeywordBubbles()
        if keywords.count >= 3 {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("这个月留下的证据词")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.text.opacity(0.88))
                    Text("优先放你亲手写下的备注；同一类太多时，先让位置给别的生活面。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext.opacity(0.78))
                }
                .padding(.horizontal, 4)

                KeywordBubbleCloudView(keywords: keywords)
                    .frame(height: 206)
            }
            .padding(.horizontal, 16)
            .padding(.top, 15)
            .padding(.bottom, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.58),
                                AppColors.monthlyInsightBg.opacity(0.38),
                                AppColors.accent.opacity(0.055)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.56), lineWidth: 1)
            )
            .shadow(color: AppColors.subtext.opacity(0.055), radius: 18, x: 0, y: 8)
        }
    }

    private var insightNextChapter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("再读一章")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.subtext.opacity(0.82))

            Button {
                showMonthlyInsightSheet = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("这一月")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.subtext.opacity(0.82))
                    Text("翻开月记 →")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.accent.opacity(0.82))
                }
                .frame(minWidth: 210, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.monthlyInsightBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.94, green: 0.82, blue: 0.68).opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                showTodayInsightSheet = true
                Task {
                    await homeViewModel.refreshTodayInsightIfNeeded(
                        userName: settingsViewModel.displayName,
                        settings: settingsViewModel.settings
                    )
                }
            } label: {
                Text("今日小记（可选） →")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.82))
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(red: 0.79, green: 0.56, blue: 0.34).opacity(0.18))
                .frame(width: 1)
        }
        .padding(.leading, 8)
    }

    private var weekKickerText: String {
        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -6, to: end) ?? end
        return "这周 · \(shortDateText(start))–\(shortDateText(end))"
    }

    private func formatWeeklyJournalText(_ blocks: (summary: String, structure: String, advice: String)) -> String {
        if blocks.summary.contains("暂无复盘") {
            return "近 7 天记录还不多。多记几笔，这里会整理成一段周记。"
        }
        let weekItems = recentPositiveItems(days: 7)
        let countText = weekItems.isEmpty ? "这周还没留下太多记录" : "这周记下 \(weekItems.count) 笔"
        let totalText = weekItems.isEmpty ? "" : "，合计 \(weekItems.reduce(0) { $0 + $1.amount }.formatted(.cny))"
        var text = "\(countText)\(totalText)。\(blocks.summary)\(blocks.structure)"
        let periodKey = EchoAnchorService.shared.periodKeyForWeek()
        // Echo priority: when weekly playback can show a highlight chapter, keep the anchor there.
        if weekItems.count < 3,
           let anchor = EchoAnchorService.shared.pickEchoAnchor(items: weekItems, periodKey: periodKey) {
            let sentence = EchoAnchorService.shared.formatEchoAnchorSentence(anchor)
            if !sentence.isEmpty {
                text += sentence
            }
        }
        return text
    }

    private func weeklyJournalClosing(_ blocks: (summary: String, structure: String, advice: String)) -> String {
        blocks.summary.contains("暂无复盘")
            ? "等记录多一点，再回来读这一周。"
            : "下周有新记录，再回来对照。"
    }

    private func recentPositiveItems(days: Int) -> [HomeItem] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(days - 1), to: Date()) ?? Date()
        return homeViewModel.items.filter { $0.createdAt >= start && $0.amount > 0 }
    }

    private func monthlyKeywordBubbles() -> [KeywordBubbleData] {
        let items = currentMonthPositiveItems
        guard !items.isEmpty else { return [] }

        let targetCount: Int
        if items.count >= 5 {
            targetCount = 6
        } else if items.count >= 3 {
            targetCount = 3
        } else {
            return []
        }

        let candidates = monthlyBubbleCandidates(from: items)
        let selected = diversifiedBubbleCandidates(candidates, targetCount: targetCount)

        return selected
            .map {
                KeywordBubbleData(
                    text: $0.text,
                    count: $0.score,
                    category: $0.category,
                    priority: $0.priority
                )
            }
    }

    private func monthlyBubbleCandidates(from items: [HomeItem]) -> [KeywordBubbleDraft] {
        var candidates: [KeywordBubbleDraft] = []
        let userTitleItems = items.compactMap { item -> (item: HomeItem, text: String)? in
            guard item.userEditedTitle == true,
                  let text = preferredBubbleTitle(from: item, allowsFullTitle: true) else {
                return nil
            }
            return (item, text)
        }
        let heroID = userTitleItems.max {
            if $0.item.amount == $1.item.amount {
                return $0.text.count < $1.text.count
            }
            return $0.item.amount < $1.item.amount
        }?.item.id

        for entry in userTitleItems {
            let isHero = entry.item.id == heroID
            let score = isHero
                ? 10_000 + Int(entry.item.amount.rounded()) + entry.text.count * 8
                : 7_000 + entry.text.count * 120 + Int(entry.item.amount.rounded())
            candidates.append(
                KeywordBubbleDraft(
                    text: entry.text,
                    score: score,
                    category: entry.item.category,
                    priority: isHero ? 0 : 1,
                    source: isHero ? .hero : .userTitle
                )
            )
        }

        for item in items where item.id != heroID {
            if let text = preferredBubbleTitle(from: item, allowsFullTitle: false) {
                candidates.append(
                    KeywordBubbleDraft(
                        text: text,
                        score: 4_000 + Int(item.amount.rounded()) + text.count * 10,
                        category: item.category,
                        priority: 2,
                        source: .amountTitle
                    )
                )
            }

            let emotion = normalizedKeyword(item.displayEmotionTag, maxLength: 10)
            if !emotion.isEmpty,
               emotion != HomeItem.inferEmotionTag(category: item.category, amount: item.amount) {
                candidates.append(
                    KeywordBubbleDraft(
                        text: emotion,
                        score: 2_000 + Int(item.amount.rounded() / 2),
                        category: item.category,
                        priority: 3,
                        source: .emotion
                    )
                )
            }
        }

        let sceneBuckets = Dictionary(grouping: items) { item in
            LifeSceneSemanticService.classify(item).kind
        }
        for (_, rows) in sceneBuckets {
            guard let scene = LifeSceneSemanticService.dominantScene(in: rows) else { continue }
            candidates.append(
                KeywordBubbleDraft(
                    text: LifeSceneSemanticService.displayTheme(for: scene.signal),
                    score: 1_000 + rows.count * 80 + Int(rows.reduce(0) { $0 + $1.amount }.rounded() / 10),
                    category: scene.signal.category,
                    priority: 4,
                    source: .category
                )
            )
        }

        return bestCandidatePerText(candidates)
    }

    private func bestCandidatePerText(_ candidates: [KeywordBubbleDraft]) -> [KeywordBubbleDraft] {
        var best: [String: KeywordBubbleDraft] = [:]
        for candidate in candidates {
            if let existing = best[candidate.text] {
                if candidate.priority < existing.priority || (candidate.priority == existing.priority && candidate.score > existing.score) {
                    best[candidate.text] = candidate
                }
            } else {
                best[candidate.text] = candidate
            }
        }
        return Array(best.values).sorted(by: bubbleCandidateSort)
    }

    private func diversifiedBubbleCandidates(_ candidates: [KeywordBubbleDraft], targetCount: Int) -> [KeywordBubbleDraft] {
        var selected: [KeywordBubbleDraft] = []
        var categoryCounts: [HomeItem.Category: Int] = [:]
        var firstThreeCategories = Set<HomeItem.Category>()

        func canPick(_ candidate: KeywordBubbleDraft, strict: Bool) -> Bool {
            if selected.contains(where: { $0.text == candidate.text }) { return false }
            if strict {
                if (categoryCounts[candidate.category] ?? 0) >= 2 { return false }
                if selected.count < 3,
                   firstThreeCategories.contains(candidate.category),
                   candidate.source != .userTitle {
                    return false
                }
            } else if (categoryCounts[candidate.category] ?? 0) >= 3 {
                return false
            }
            return true
        }

        func pick(_ candidate: KeywordBubbleDraft) {
            selected.append(candidate)
            categoryCounts[candidate.category, default: 0] += 1
            if selected.count <= 3 {
                firstThreeCategories.insert(candidate.category)
            }
        }

        for candidate in candidates where selected.count < targetCount {
            if canPick(candidate, strict: true) { pick(candidate) }
        }

        for candidate in candidates where selected.count < targetCount {
            if canPick(candidate, strict: false) { pick(candidate) }
        }

        return selected.sorted(by: bubbleCandidateSort)
    }

    private func bubbleCandidateSort(_ lhs: KeywordBubbleDraft, _ rhs: KeywordBubbleDraft) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        return lhs.text < rhs.text
    }

    private func preferredBubbleTitle(from item: HomeItem, allowsFullTitle: Bool) -> String? {
        guard item.hasMeaningfulTitle else { return nil }
        let keywords = titleKeywords(from: item.title, allowsFullTitle: allowsFullTitle)
        guard let first = keywords.first else { return nil }
        if !allowsFullTitle,
           item.userEditedTitle != true,
           !EchoAnchorService.shared.isEligibleLifeTraceTitle(item.title, item: item),
           first == item.category.rawValue {
            return nil
        }
        return first
    }

    private func normalizedKeyword(_ raw: String, maxLength: Int = 12) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let noiseWords = ["记录", "记下", "记下来", "消费", "安排", "这一笔", "这笔", "一笔", "一条", "一下", "一点", "小消费", "日常记录", "临时花了"]
        for word in noiseWords {
            text = text.replacingOccurrences(of: word, with: "")
        }
        text = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        if text.count < 2 || text.count > maxLength { return "" }
        if isFillerKeyword(text) { return "" }
        if text.rangeOfCharacter(from: .decimalDigits) != nil { return "" }
        return text
    }

    private func titleKeywords(from title: String, allowsFullTitle: Bool) -> [String] {
        let normalized = normalizedKeyword(title)
        if allowsFullTitle, !normalized.isEmpty, normalized.count <= 12, !isGenericRecordTitle(normalized) {
            return [normalized]
        }

        let candidates = ["咖啡", "奶茶", "早餐", "午餐", "晚餐", "夜宵", "打车", "地铁", "公交", "停车", "超市", "便利店", "水果", "药", "运动", "健身", "宠物", "电影", "外卖", "食堂", "热饭"]
        return candidates.filter { title.contains($0) }
    }

    private func isGenericRecordTitle(_ title: String) -> Bool {
        HomeItem.Category.allCases.contains { category in
            title == category.rawValue || title == category.label || title == category.defaultRecordTitle
        }
    }

    private func isFillerKeyword(_ text: String) -> Bool {
        let fillers: Set<String> = [
            "一笔", "几笔", "这笔", "小记", "今天", "昨天", "本周", "本月",
            "生活", "日常", "花了", "花钱", "补一下", "临时", "简单"
        ]
        return fillers.contains(text)
    }

    private func shortDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private var weeklyInsightSection: some View {
        let weeklyBlocks = homeViewModel.localWeeklyInsightBlocks()

        return VStack(alignment: .leading, spacing: 12) {
            Text("近 7 天生活复盘")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)

            weeklyInsightText(weeklyBlocks)

            Text(homeViewModel.buildWeeklyRhythmText())
                .font(.system(size: 13))
                .lineSpacing(4)
                .foregroundStyle(AppColors.text.opacity(0.78))

            quietTextButton("保存周记摘页") {
                showWeeklySharePrivacyConfirm = true
            }
            if let weeklyShareSaveMessage {
                Text(weeklyShareSaveMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
            }
        }
        .glassPanel(radius: 24, padding: 20)
    }

    @ViewBuilder
    private func weeklyInsightText(_ weeklyBlocks: (summary: String, structure: String, advice: String)) -> some View {
        if weeklyBlocks.summary.contains("暂无复盘") {
            Text(weeklyBlocks.summary)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(weeklyBlocks.summary)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.text)
                Text(weeklyBlocks.structure)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
                Text(weeklyBlocks.advice)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
            }
        }
    }

    private var monthlyInsightSection: some View {
        let left = max(0, trialTotal - monthlyTrialUsed)
        let isMember = hasMemberAccess
        let exhausted = !isMember && monthlyTrialUsed >= trialTotal

        return VStack(alignment: .leading, spacing: 12) {
            Text("月度生活复盘")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)

            monthlyGenerateControl(isMember: isMember, exhausted: exhausted)
            monthlyTrialText(left: left, isMember: isMember, exhausted: exhausted)
            if monthlyInsightGenerated || homeViewModel.isGeneratingMonthlyInsight || monthlyAIStatus?.kind == .error {
                monthlyAIStatusView
            }
            monthlyErrorView
            monthlyReportView
            advancedInsightToggle
            advancedInsightContent
        }
        .glassPanel(radius: 24, padding: 20)
    }

    @ViewBuilder
    private func monthlyTrialText(left: Int, isMember: Bool, exhausted: Bool) -> some View {
        if !isMember {
            let text = exhausted
                ? "月度回顾剩余 0/\(trialTotal) 次 · 会员可继续多问几句"
                : "月度回顾剩余 \(left)/\(trialTotal) 次 · 可先看看这个月的生活线索"

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.86))
        }
    }

    @ViewBuilder
    private func monthlyGenerateControl(isMember: Bool, exhausted: Bool) -> some View {
        if exhausted {
            Button {
                onShowMemberPricing?()
            } label: {
                monthlyUpgradeLinkLabel
            }
            .buttonStyle(.plain)
        } else {
            Button {
                Task {
                    await generateMonthlyInsight(isMember: isMember)
                }
            } label: {
                monthlyGenerateButtonLabel
            }
            .buttonStyle(.plain)
            .disabled(homeViewModel.isGeneratingMonthlyInsight)
        }
    }

    private var monthlyUpgradeLinkLabel: some View {
        Text("想继续追问这个月？了解会员")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppColors.accent.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
    }

    private var monthlyGenerateButtonLabel: some View {
        let title = homeViewModel.isGeneratingMonthlyInsight ? "正在梳理这一月..." : "生成这一月的回顾"

        return Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.accent.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.accent.opacity(0.18), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var monthlyAIStatusView: some View {
        if let status = monthlyAIStatus ?? defaultMonthlyAIStatus {
            aiStatusPill(status)
        }
    }

    @ViewBuilder
    private var monthlyErrorView: some View {
        if let error = homeViewModel.insightErrorMessage,
           monthlyAIStatus?.kind == .error {
            monthlyErrorText(error)
        }
    }

    private func monthlyErrorText(_ error: String) -> some View {
        let foreground = Color.orange.opacity(0.9)
        let fill = Color.orange.opacity(0.08)
        let stroke = Color.orange.opacity(0.22)

        return Text(error)
            .font(.system(size: 11))
            .foregroundStyle(foreground)
            .lineLimit(3)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var monthlyReportView: some View {
        if monthlyInsightGenerated, let report = monthlyReport {
            VStack(alignment: .leading, spacing: 8) {
                Text(report.summary)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.text)
                Text(report.structure)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
                Text(report.advice)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.text)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.accent.opacity(0.22), lineWidth: 1)
            )

            softActionButton("记一句本月收束") {
                homeViewModel.markMonthlyClosing()
            }
            softActionButton("保存月记") {
                saveMonthlySummary()
            }
            softActionButton("换一版") {
                changeMonthlyNarrativeStyle()
            }
            if let monthlyActionMessage {
                Text(monthlyActionMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.78))
            }
        }
    }

    private var advancedInsightToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showAdvancedInsight.toggle()
            }
        } label: {
            Text(showAdvancedInsight ? "收起更多复盘" : "查看更多复盘")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.subtext.opacity(0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var advancedInsightContent: some View {
        if showAdvancedInsight {
            if !hasMemberAccess {
                Button {
                    onShowMemberPricing?()
                } label: {
                    lockedReportButton("生成季度复盘")
                }
                .buttonStyle(.plain)
                Button {
                    onShowMemberPricing?()
                } label: {
                    lockedReportButton("生成年度复盘")
                }
                .buttonStyle(.plain)
            } else {
                Text("季度 / 年度复盘正在打磨中，先从每周和每月开始回看。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
            }
        }
    }

    private var todayInsightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTodayInsightExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("今日小记（可选）")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.text.opacity(0.86))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.subtext.opacity(0.7))
                        .rotationEffect(.degrees(isTodayInsightExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isTodayInsightExpanded {
                todayInsightText
                todayRegenerateButton
                todayInsightLoading
                todayInsightError
            }
        }
        .glassPanel(radius: 20, padding: 18)
    }

    @ViewBuilder
    private var todayInsightText: some View {
        if let insight = homeViewModel.todayInsight {
            Text(insight.summary)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.text)
            Text(insight.action)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.text)
            Text(insight.encourage)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
        } else {
            Text("还没有今日复盘。")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)
        }
    }

    private var todayRegenerateButton: some View {
        Button("换个说法再读") {
            Task {
                await homeViewModel.regenerateTodayInsight(
                    userName: settingsViewModel.displayName,
                    settings: settingsViewModel.settings
                )
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(AppColors.subtext.opacity(0.88))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var todayInsightLoading: some View {
        if homeViewModel.isGeneratingInsight {
            HStack(spacing: 8) {
                ProgressView()
                Text("正在整理今天的小记…")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var todayInsightError: some View {
        if let error = homeViewModel.insightErrorMessage {
            Text(error)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.subtext)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(red: 255/255, green: 246/255, blue: 222/255).opacity(0.78))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color(red: 228/255, green: 201/255, blue: 134/255).opacity(0.48), lineWidth: 1)
                )
        }
    }

    private var monthlyInsightSheet: some View {
        let left = max(0, trialTotal - monthlyTrialUsed)
        let isMember = hasMemberAccess
        let exhausted = !isMember && monthlyTrialUsed >= trialTotal

        return ZStack {
            AppColors.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(monthlyKickerText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.subtext.opacity(0.78))

                    VStack(alignment: .leading, spacing: 12) {
                        Text(monthlyJournalText)
                            .font(.system(size: 17, weight: .medium))
                            .lineSpacing(6)
                            .foregroundStyle(AppColors.text)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(monthlyJournalClosingText)
                            .font(.system(size: 13))
                            .italic()
                            .foregroundStyle(AppColors.subtext.opacity(0.84))
                            .fixedSize(horizontal: false, vertical: true)

                        monthlyJournalFootnote(left: left, isMember: isMember, exhausted: exhausted)
                    }
                    .padding(.leading, 4)
                    .paperChapterPanel(radius: 22, padding: 20)
                }
                .padding(18)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            Task {
                await homeViewModel.refreshTodayInsightIfNeeded(
                    userName: settingsViewModel.displayName,
                    settings: settingsViewModel.settings
                )
            }
        }
    }

    private var todayInsightSheet: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("今日小记")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.subtext.opacity(0.78))

                    todayInsightText
                    todayRegenerateButton
                    todayInsightLoading
                    todayInsightError
                }
                .padding(20)
                .glassPanel(radius: 22, padding: 20)
                .padding(18)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func monthlyJournalFootnote(left: Int, isMember: Bool, exhausted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color(red: 0.94, green: 0.82, blue: 0.68).opacity(0.30))
                .frame(height: 1)
                .padding(.top, 6)
                .padding(.bottom, 12)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if exhausted {
                    Button {
                        onShowMemberPricing?()
                    } label: {
                        monthlyFootnotePrimary("想继续追问这个月？了解会员 →")
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        Task {
                            await generateMonthlyInsight(isMember: isMember)
                        }
                    } label: {
                        monthlyFootnotePrimary(monthlyInsightGenerated ? "再写一版 →" : "生成这一月的回顾 →")
                    }
                    .buttonStyle(.plain)
                    .disabled(homeViewModel.isGeneratingMonthlyInsight)
                }

                if !isMember {
                    Text(exhausted ? "剩余 0/\(trialTotal) 次" : "剩余 \(left)/\(trialTotal) 次")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext.opacity(0.58))
                }
            }

            if monthlyInsightGenerated || homeViewModel.isGeneratingMonthlyInsight || monthlyAIStatus?.kind == .error {
                monthlyAIStatusView
                    .padding(.top, 8)
            }
            monthlyErrorView
                .padding(.top, 6)

            if monthlyInsightGenerated, monthlyReport != nil, !homeViewModel.isGeneratingMonthlyInsight {
                HStack(spacing: 6) {
                    monthlyFootnoteSecondaryButton("保存月记") {
                        saveMonthlySummary()
                    }
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext.opacity(0.45))
                    monthlyFootnoteSecondaryButton("换一版") {
                        changeMonthlyNarrativeStyle()
                    }
                }
                .padding(.top, 10)
            }

            if let monthlyActionMessage {
                Text(monthlyActionMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.accent.opacity(0.72))
                    .padding(.top, 8)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAdvancedInsight.toggle()
                }
            } label: {
                Text(showAdvancedInsight ? "收起更多时间段" : "更多时间段")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppColors.subtext.opacity(0.56))
                    .padding(.top, 16)
            }
            .buttonStyle(.plain)

            advancedInsightContent
                .padding(.top, 12)
        }
    }

    private func monthlyFootnotePrimary(_ title: String) -> some View {
        Text(homeViewModel.isGeneratingMonthlyInsight ? "正在梳理这一月..." : title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppColors.accent.opacity(0.82))
    }

    private func monthlyFootnoteSecondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.74))
        }
        .buttonStyle(.plain)
    }

    private var monthlyKickerText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return "这一月 · \(formatter.string(from: Date()))"
    }

    private var monthlyJournalText: String {
        if homeViewModel.isGeneratingMonthlyInsight {
            return "正在梳理这一月..."
        }
        if monthlyInsightGenerated, let report = monthlyReport {
            return formatMonthlyJournalText(report, variant: monthlyNarrativeVariant)
        }
        return "这一月还没有回顾。生成后，这里会写成一段月记。"
    }

    private var monthlyJournalClosingText: String {
        if homeViewModel.isGeneratingMonthlyInsight {
            return ""
        }
        if monthlyInsightGenerated, monthlyReport != nil {
            return "下个月有新记录，再翻开对照。"
        }
        return "先放在这里，想读的时候再打开。"
    }

    private func formatMonthlyJournalText(_ report: HomeViewModel.MonthlyInsightReport, variant: Int) -> String {
        let monthItems = currentMonthPositiveItems
        guard !monthItems.isEmpty else {
            return "这一月还没有足够记录，月记先留一页空白。"
        }
        let top = Dictionary(grouping: monthItems, by: \.category)
            .map { (category: $0.key, count: $0.value.count, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
            .first?.category.rawValue ?? "日常"
        let total = monthItems.reduce(0) { $0 + $1.amount }
        let opening: String
        switch variant % 3 {
        case 1:
            opening = "换个角度读：这个月留下 \(monthItems.count) 笔，\(total.formatted(.cny)) 记在账本里，「\(top)」是最清楚的一类。"
        case 2:
            opening = "换个写法：这个月留下 \(monthItems.count) 笔，\(total.formatted(.cny)) 记在账本里，「\(top)」更靠前。"
        default:
            opening = "这个月记下来 \(monthItems.count) 笔，\(total.formatted(.cny)) 留在账本里，「\(top)」出现得多一些。"
        }
        var text = "\(opening)\(report.structure)"
        let periodKey = EchoAnchorService.shared.periodKeyForMonth()
        if let anchor = EchoAnchorService.shared.pickEchoAnchor(items: monthItems, periodKey: periodKey) {
            let sentence = EchoAnchorService.shared.formatEchoAnchorSentence(anchor)
            if !sentence.isEmpty {
                text += sentence
            }
        }
        return text
    }

    private func saveMonthlySummary() {
        homeViewModel.markMonthlySaveSummary()
        withAnimation(.easeInOut(duration: 0.2)) {
            monthlyActionMessage = "已保存到叙账回望里。"
        }
    }

    private func changeMonthlyNarrativeStyle() {
        homeViewModel.regenerateMonthlyInsight()
        withAnimation(.easeInOut(duration: 0.2)) {
            monthlyNarrativeVariant = (monthlyNarrativeVariant + 1) % 3
            monthlyActionMessage = "已换成另一种月记语气。"
        }
    }

    private var currentMonthPositiveItems: [HomeItem] {
        homeViewModel.items.filter {
            Calendar.current.isDate($0.createdAt, equalTo: Date(), toGranularity: .month) && $0.amount > 0
        }
    }

    private func monthlyTrialOverlay(_ modal: MonthlyTrialModal) -> some View {
        ZStack {
            trialOverlayBackdrop
            trialOverlayCard(modal)
        }
    }

    private var trialOverlayBackdrop: some View {
        Color.black.opacity(0.26)
            .ignoresSafeArea()
            .onTapGesture {
                monthlyTrialModal = nil
            }
    }

    private func trialOverlayCard(_ modal: MonthlyTrialModal) -> some View {
        VStack(spacing: 18) {
            trialOverlayCopy(modal)
            trialOverlayActions
        }
        .padding(28)
        .frame(maxWidth: 390)
        .background(trialOverlayCardBackground)
        .overlay(trialOverlayCardBorder)
        .shadow(color: Color.black.opacity(0.14), radius: 22, x: 0, y: 10)
        .padding(.horizontal, 28)
    }

    private func trialOverlayCopy(_ modal: MonthlyTrialModal) -> some View {
        VStack(spacing: 18) {
            Text(modal.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.text)
                .multilineTextAlignment(.center)

            Text(modal.body)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.subtext)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var trialOverlayActions: some View {
        HStack(spacing: 14) {
            trialOverlayDismissButton
            trialOverlayUpgradeButton
        }
    }

    private var trialOverlayDismissButton: some View {
        Button {
            monthlyTrialModal = nil
        } label: {
            trialOverlayButtonLabel(
                "我知道了",
                foreground: AppColors.text,
                background: Color.white.opacity(0.72),
                weight: .medium
            )
        }
        .buttonStyle(.plain)
    }

    private var trialOverlayUpgradeButton: some View {
        Button {
            monthlyTrialModal = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                onShowMemberPricing?()
            }
        } label: {
            trialOverlayButtonLabel(
                "让复盘不中断",
                foreground: .white,
                background: AppColors.accent.opacity(0.86),
                weight: .semibold
            )
        }
        .buttonStyle(.plain)
    }

    private func trialOverlayButtonLabel(
        _ title: String,
        foreground: Color,
        background: Color,
        weight: Font.Weight
    ) -> some View {
        Text(title)
            .font(.system(size: 16, weight: weight))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var trialOverlayCardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppColors.panel)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }

    private var trialOverlayCardBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.66), lineWidth: 1)
    }

    private var weeklySharePrivacyOverlay: some View {
        ZStack {
            Color(red: 28/255, green: 36/255, blue: 42/255)
                .opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture {
                    showWeeklySharePrivacyConfirm = false
                }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.accent.opacity(0.92))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(AppColors.accent.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 7) {
                        Text("保存周记摘页")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColors.text)

                        Text("摘页里可能有昵称、金额区间和你写下的回望。保存后先看一眼内容，再发给别人。")
                            .font(.system(size: 14))
                            .lineSpacing(4)
                            .foregroundStyle(AppColors.subtext.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        showWeeklySharePrivacyConfirm = false
                    } label: {
                        Text("先不保存")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.text.opacity(0.82))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.66))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showWeeklySharePrivacyConfirm = false
                        homeViewModel.markWeeklyShareGenerated()
                        generateAndShareWeeklyCard()
                    } label: {
                        Text("保存到相册")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                LinearGradient(
                                    colors: [AppColors.accent.opacity(0.92), AppColors.accentDark.opacity(0.90)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSavingWeeklyShareCard)
                    .opacity(isSavingWeeklyShareCard ? 0.62 : 1)
                }
            }
            .padding(22)
            .frame(maxWidth: 370)
            .background(weeklySharePrivacyCardBackground)
            .overlay(weeklySharePrivacyCardBorder)
            .shadow(color: Color(red: 47/255, green: 67/255, blue: 58/255).opacity(0.18), radius: 24, x: 0, y: 12)
            .padding(.horizontal, 24)
        }
    }

    private var weeklySharePrivacyCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.96),
                        AppColors.paperWarm.opacity(0.72),
                        AppColors.paperMist.opacity(0.70)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
            )
    }

    private var weeklySharePrivacyCardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.82),
                        AppColors.accent.opacity(0.16),
                        AppColors.paperBorder.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var defaultMonthlyAIStatus: AIStatusPill? {
        if homeViewModel.isGeneratingMonthlyInsight {
            return settingsViewModel.useRemoteAI
                ? AIStatusPill(kind: .live, text: "正在写这一月")
                : AIStatusPill(kind: .fallback, text: "正在用本地记录写这一月")
        }
        guard settingsViewModel.useRemoteAI else { return nil }
        let endpoint = settingsViewModel.aiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDirectModelEndpoint = endpoint.isEmpty || endpoint.contains("open.bigmodel.cn")
        if isDirectModelEndpoint && KeychainService.loadAIAPIKey().isEmpty {
            return AIStatusPill(kind: .error, text: "本地计算，AI Key 未配置")
        }
        return nil
    }

    private func aiStatusPill(_ status: AIStatusPill) -> some View {
        let palette: (fg: Color, bg: Color, border: Color)
        switch status.kind {
        case .live:
            palette = (
                AppColors.accent.opacity(0.95),
                AppColors.accent.opacity(0.13),
                AppColors.accent.opacity(0.28)
            )
        case .fallback:
            palette = (
                Color(red: 128/255, green: 98/255, blue: 42/255),
                Color(red: 255/255, green: 246/255, blue: 222/255).opacity(0.82),
                Color(red: 228/255, green: 201/255, blue: 134/255).opacity(0.55)
            )
        case .error:
            palette = (
                Color.orange.opacity(0.88),
                Color.orange.opacity(0.12),
                Color.orange.opacity(0.28)
            )
        }

        return HStack(spacing: 6) {
            Circle()
                .fill(palette.fg)
                .frame(width: 8, height: 8)
            Text(status.text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(palette.fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule(style: .continuous).fill(palette.bg))
        .overlay(
            Capsule(style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }

    private func generateMonthlyInsight(isMember: Bool) async {
        let firstTime = !isMember && monthlyTrialUsed == 0
        monthlyAIStatus = settingsViewModel.useRemoteAI
            ? AIStatusPill(kind: .live, text: "正在写这一月")
            : AIStatusPill(kind: .fallback, text: "正在用本地记录写这一月")

        let report = await homeViewModel.generateMonthlyInsight(settings: settingsViewModel.settings)

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.25)) {
                monthlyReport = report
                monthlyInsightGenerated = true
                monthlyAIStatus = aiStatus(for: report.source)
                monthlyActionMessage = nil
            }

            guard !isMember else { return }
            monthlyTrialUsed += 1
            UserDefaults.standard.set(monthlyTrialUsed, forKey: "monthly_trial_used_v1")
            let left = max(0, trialTotal - monthlyTrialUsed)
            monthlyTrialModal = firstTime
                ? MonthlyTrialModal(
                    title: "月记写好了",
                    body: "这次先用掉 1 次月度回顾体验，还剩 \(left) 次。"
                )
                : MonthlyTrialModal(
                    title: "月度复盘已生成",
                    body: "这次用掉 1 次月度回顾体验，还剩 \(left) 次。"
                )
        }
    }

    private func aiStatus(for source: HomeViewModel.AIInsightSource) -> AIStatusPill {
        switch source {
        case .live:
            return AIStatusPill(kind: .live, text: "已写好这一月")
        case .fallback:
            return AIStatusPill(kind: .fallback, text: "已用本地记录写好")
        case .errorFallback:
            return AIStatusPill(kind: .error, text: "本地计算，远程 AI 未接通")
        }
    }

    private func primaryActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColors.accent.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.accent.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func quietTextButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title.replacingOccurrences(of: " →", with: ""))
                if title.contains("→") {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColors.subtext.opacity(0.9))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.34))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(AppColors.accent.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func softActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.84))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.4), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(0.985)
        .animation(.easeOut(duration: 0.1), value: UUID())
    }

    private func lockedReportButton(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
            Spacer()
            Text("会员可用")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(AppColors.subtext.opacity(0.86))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.subtext.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Share Card Generation

    private func generateAndShareWeeklyCard() {
        guard !isSavingWeeklyShareCard,
              let payload = PlaybackService().buildWeeklyShareCardPayload(from: homeViewModel.items) else { return }
        let petMode = settingsViewModel.petCompanionEnabled
        let nick = settingsViewModel.displayName.isEmpty ? "叙账用户" : settingsViewModel.displayName
        let card = WeeklyShareCardView(
            payload: payload,
            isPetMode: petMode,
            nickname: nick
        )
        guard let img = card.snapshot() else { return }
        isSavingWeeklyShareCard = true
        weeklyShareSaveMessage = nil
        Task {
            do {
                try await PhotoLibrarySaveService.shared.saveImageToLibrary(img)
                weeklyShareSaveMessage = "已保存到相册。"
            } catch {
                weeklyShareSaveMessage = (error as? LocalizedError)?.errorDescription ?? "暂时没保存成功。请检查相册权限后再试。"
            }
            isSavingWeeklyShareCard = false
        }
    }
}

// MARK: - Keyword Bubble Cloud

private struct KeywordBubbleDraft {
    enum Source {
        case hero
        case userTitle
        case amountTitle
        case emotion
        case category
    }

    let text: String
    let score: Int
    let category: HomeItem.Category
    var priority: Int
    let source: Source
}

private struct KeywordBubbleData: Identifiable, Equatable {
    let id: String
    let text: String
    let count: Int
    let category: HomeItem.Category
    let priority: Int

    init(text: String, count: Int, category: HomeItem.Category, priority: Int) {
        self.id = "\(category.rawValue)-\(text)"
        self.text = text
        self.count = count
        self.category = category
        self.priority = priority
    }
}

private struct KeywordBubbleCloudView: View {
    let keywords: [KeywordBubbleData]

    private struct BubbleLayout: Identifiable {
        let id: String
        let keyword: KeywordBubbleData
        let center: CGPoint
        let radius: CGFloat
        let fontSize: CGFloat
        let weight: Double
        let delay: Double
        let palette: KeywordBubblePalette
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = bubbleLayout(in: proxy.size)
            ZStack {
                ForEach(layout) { bubble in
                    KeywordBubbleView(
                        text: bubble.keyword.text,
                        count: bubble.keyword.count,
                        radius: bubble.radius,
                        fontSize: bubble.fontSize,
                        weight: bubble.weight,
                        delay: bubble.delay,
                        palette: bubble.palette
                    )
                    .position(bubble.center)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .accessibilityElement(children: .contain)
        }
    }

    private func bubbleLayout(in size: CGSize) -> [BubbleLayout] {
        guard size.width > 80, size.height > 120 else { return [] }
        let sorted = keywords
            .sorted {
                if $0.priority != $1.priority { return $0.priority < $1.priority }
                if $0.count == $1.count { return $0.text < $1.text }
                return $0.count > $1.count
            }
            .prefix(7)

        guard let maxCount = sorted.map(\.count).max(),
              let minCount = sorted.map(\.count).min() else { return [] }

        let center = CGPoint(x: size.width * 0.52, y: size.height * 0.43)
        let countRange = max(maxCount - minCount, 1)
        var placed: [BubbleLayout] = []

        for (index, keyword) in sorted.enumerated() {
            let weight = Double(keyword.count - minCount) / Double(countRange)
            let easedWeight = sqrt(weight)
            let radius = CGFloat(34 + easedWeight * 24)
            let fontSize = CGFloat(12 + easedWeight * 6)
            let delay = Double(stableHash(keyword.text) % 2_000) / 1_000
            let layout = BubbleLayout(
                id: keyword.id,
                keyword: keyword,
                center: position(
                    for: keyword.text,
                    index: index,
                    radius: radius,
                    preferredCenter: center,
                    bounds: size,
                    placed: placed
                ),
                radius: radius,
                fontSize: min(fontSize, 18),
                weight: weight,
                delay: delay,
                palette: KeywordBubblePalette.palette(for: keyword.category, isTitle: keyword.priority == 0)
            )
            placed.append(layout)
        }

        return placed
    }

    private func position(
        for text: String,
        index: Int,
        radius: CGFloat,
        preferredCenter: CGPoint,
        bounds: CGSize,
        placed: [BubbleLayout]
    ) -> CGPoint {
        let motionPadding: CGFloat = 14
        let inset = radius + motionPadding
        let safeBounds = CGRect(
            x: inset,
            y: inset,
            width: max(bounds.width - inset * 2, 1),
            height: max(bounds.height - inset * 2, 1)
        )

        if index == 0 {
            return CGPoint(
                x: min(max(preferredCenter.x, safeBounds.minX), safeBounds.maxX),
                y: min(max(preferredCenter.y, safeBounds.minY), safeBounds.maxY)
            )
        }

        let seed = stableHash(text)
        let baseAngle = CGFloat(seed % 360) * .pi / 180
        let verticalSquash: CGFloat = 0.78
        let gap: CGFloat = 18
        var bestCandidate: CGPoint?
        var bestScore = -CGFloat.greatestFiniteMagnitude

        for attempt in 0..<260 {
            let angle = baseAngle + CGFloat(attempt) * 0.53
            let distance = CGFloat(34 + attempt * 4)
            let raw = CGPoint(
                x: preferredCenter.x + cos(angle) * distance,
                y: preferredCenter.y + sin(angle) * distance * verticalSquash
            )
            let candidate = clamped(raw, in: safeBounds)
            let score = clearanceScore(for: candidate, radius: radius, placed: placed, gap: gap)
            if score > bestScore {
                bestScore = score
                bestCandidate = candidate
            }
            if score >= 0 {
                return candidate
            }
        }

        for anchor in fallbackAnchors(index: index, bounds: bounds) {
            let candidate = clamped(anchor, in: safeBounds)
            let score = clearanceScore(for: candidate, radius: radius, placed: placed, gap: gap)
            if score > bestScore {
                bestScore = score
                bestCandidate = candidate
            }
            if score >= 0 {
                return candidate
            }
        }

        return bestCandidate ?? CGPoint(x: safeBounds.midX, y: safeBounds.midY)
    }

    private func clamped(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        return CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private func clearanceScore(
        for candidate: CGPoint,
        radius: CGFloat,
        placed: [BubbleLayout],
        gap: CGFloat
    ) -> CGFloat {
        guard !placed.isEmpty else { return .greatestFiniteMagnitude }
        return placed
            .map { other in
                hypot(candidate.x - other.center.x, candidate.y - other.center.y) - (radius + other.radius + gap)
            }
            .min() ?? .greatestFiniteMagnitude
    }

    private func fallbackAnchors(index: Int, bounds: CGSize) -> [CGPoint] {
        let anchors = [
            CGPoint(x: bounds.width * 0.18, y: bounds.height * 0.30),
            CGPoint(x: bounds.width * 0.78, y: bounds.height * 0.34),
            CGPoint(x: bounds.width * 0.24, y: bounds.height * 0.70),
            CGPoint(x: bounds.width * 0.74, y: bounds.height * 0.72),
            CGPoint(x: bounds.width * 0.50, y: bounds.height * 0.78),
            CGPoint(x: bounds.width * 0.16, y: bounds.height * 0.55),
            CGPoint(x: bounds.width * 0.84, y: bounds.height * 0.56)
        ]
        let offset = index % anchors.count
        return anchors.indices.map { anchors[($0 + offset) % anchors.count] }
    }

    private func stableHash(_ text: String) -> UInt64 {
        text.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { partial, scalar in
            (partial ^ UInt64(scalar.value)) &* 1_099_511_628_211
        }
    }
}

private struct KeywordBubblePalette {
    let base: Color
    let rim: Color
    let glow: Color
    let text: Color

    static func palette(for category: HomeItem.Category, isTitle: Bool) -> KeywordBubblePalette {
        let baseOpacity = isTitle ? 0.38 : 0.26
        let rimOpacity = isTitle ? 0.34 : 0.24
        let glowOpacity = isTitle ? 0.22 : 0.16
        switch category {
        case .dining, .shopping, .social:
            return .init(
                base: Color(red: 0.84, green: 0.70, blue: 0.44).opacity(baseOpacity),
                rim: Color(red: 0.70, green: 0.56, blue: 0.34).opacity(rimOpacity),
                glow: Color(red: 0.90, green: 0.78, blue: 0.52).opacity(glowOpacity),
                text: AppColors.text.opacity(0.86)
            )
        case .transport, .entertainment:
            return .init(
                base: Color(red: 0.58, green: 0.67, blue: 0.76).opacity(baseOpacity),
                rim: Color(red: 0.45, green: 0.54, blue: 0.65).opacity(rimOpacity),
                glow: Color(red: 0.63, green: 0.75, blue: 0.83).opacity(glowOpacity),
                text: AppColors.text.opacity(0.85)
            )
        case .daily, .lodging, .health, .home, .other:
            return .init(
                base: AppColors.accent.opacity(isTitle ? 0.34 : 0.22),
                rim: AppColors.accentDark.opacity(rimOpacity),
                glow: AppColors.accent.opacity(isTitle ? 0.20 : 0.13),
                text: AppColors.text.opacity(0.86)
            )
        }
    }
}

private struct KeywordBubbleView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let text: String
    let count: Int
    let radius: CGFloat
    let fontSize: CGFloat
    let weight: Double
    let delay: Double
    let palette: KeywordBubblePalette

    private var diameter: CGFloat { radius * 2 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let phase = reduceMotion ? 0 : phaseValue(at: timeline.date)
            Text(text)
                .font(.system(size: fontSize, weight: weight > 0.72 ? .bold : .semibold, design: .rounded))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .frame(width: diameter, height: diameter)
                .background(bubbleBackground(phase: phase))
                .scaleEffect(reduceMotion ? 1 : 1 + sin(phase) * 0.018)
                .opacity(reduceMotion ? 1 : 0.95 + cos(phase) * 0.035)
                .offset(
                    x: reduceMotion ? 0 : cos(phase * 0.72) * 1.8,
                    y: reduceMotion ? 0 : sin(phase) * 5.5
                )
                .shadow(color: palette.glow.opacity(0.70), radius: weight > 0.6 ? 22 : 16, x: 0, y: 12)
                .accessibilityLabel("\(text)，出现 \(count) 次")
        }
    }

    private func phaseValue(at date: Date) -> Double {
        let duration = 4.2 + (delay * 0.9)
        return ((date.timeIntervalSinceReferenceDate + delay) / duration) * .pi * 2
    }

    private func bubbleBackground(phase: Double) -> some View {
        let lightCenter = UnitPoint(
            x: 0.36 + sin(phase * 0.6) * 0.08,
            y: 0.28 + cos(phase * 0.5) * 0.06
        )

        return ZStack {
            Circle()
                .fill(.ultraThinMaterial)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.74),
                            palette.base,
                            palette.rim.opacity(0.42),
                            Color.white.opacity(0.08)
                        ],
                        center: lightCenter,
                        startRadius: 0,
                        endRadius: diameter * 0.64
                    )
                )

            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.74),
                            palette.rim.opacity(0.48),
                            Color.white.opacity(0.16),
                            palette.base.opacity(0.44),
                            Color.white.opacity(0.74)
                        ],
                        center: .center,
                        angle: .degrees(phase * 12)
                    ),
                    lineWidth: weight > 0.72 ? 1.2 : 0.9
                )

            Circle()
                .trim(from: 0.03, to: 0.24)
                .stroke(Color.white.opacity(0.38), lineWidth: 1.2)
                .rotationEffect(.degrees(phase * 11 + 210))
                .blur(radius: 0.3)

            Circle()
                .fill(palette.glow)
                .blur(radius: 15)
                .scaleEffect(0.82 + sin(phase * 0.85) * 0.04)
                .opacity(0.55)
        }
        .clipShape(Circle())
    }
}

// MARK: - Weekly Share Card

struct WeeklyShareCardView: View {
    let weekTotal: Double
    let topCategory: String
    let recordCount: Int
    let primaryMetricCount: Int
    let primaryMetricEmoji: String
    let dailyTrend: [(String, Double)]
    let dailyCountTrend: [(String, Int)]
    let categorySlices: [WeeklyShareCategorySlice]
    let topCategoryRatio: Double
    let headline: String
    let subtitle: String
    let anchorLine: String?
    let periodText: String
    let insight: ShareInsight
    var isPetMode: Bool = true
    var nickname: String = "叙账用户"

    private var t: ShareCardTheme { .journal }

    struct ShareCardTheme {
        let bgStart, bgMid, bgEnd: Color; let panelBg, panelBorder: Color
        let paperShadow, paperEdge: Color
        let accent, accentDeep, titleSub, textMain, textMuted: Color
        let footer, footerSub: Color
        static let journal = ShareCardTheme(
            bgStart: Color(hex: "dceadf"), bgMid: Color(hex: "f5f7ec"), bgEnd: Color(hex: "fff3df"),
            panelBg: Color(hex: "fffdf7").opacity(0.94), panelBorder: Color(hex: "dbe4d5"),
            paperShadow: Color(hex: "6f8374"), paperEdge: Color(hex: "f1f5e9"),
            accent: Color(hex: "89b69a"), accentDeep: Color(hex: "47705c"),
            titleSub: Color(hex: "89968f"), textMain: Color(hex: "1f2528"), textMuted: Color(hex: "6d776f"),
            footer: Color(hex: "4c5960"), footerSub: Color(hex: "9aa49b"))
    }

    init(
        weekTotal: Double,
        topCategory: String,
        recordCount: Int,
        primaryMetricCount: Int? = nil,
        primaryMetricEmoji: String = "📝",
        dailyTrend: [(String, Double)],
        dailyCountTrend: [(String, Int)]? = nil,
        categorySlices: [WeeklyShareCategorySlice] = [],
        topCategoryRatio: Double,
        headline: String = "这一周留下几笔记录",
        subtitle: String = "之后有新记录，再回来对照。",
        anchorLine: String? = nil,
        periodText: String? = nil,
        insight: ShareInsight? = nil,
        isPetMode: Bool = true,
        nickname: String = "叙账用户"
    ) {
        self.weekTotal = weekTotal
        self.topCategory = topCategory
        self.recordCount = recordCount
        self.primaryMetricCount = primaryMetricCount ?? recordCount
        self.primaryMetricEmoji = primaryMetricEmoji
        self.dailyTrend = dailyTrend
        self.dailyCountTrend = dailyCountTrend ?? dailyTrend.map { ($0.0, Int($0.1.rounded())) }
        self.categorySlices = categorySlices
        self.topCategoryRatio = topCategoryRatio
        self.headline = headline
        self.subtitle = subtitle
        self.anchorLine = anchorLine
        self.periodText = periodText ?? Self.defaultPeriodText()
        self.insight = insight ?? ShareInsight(
            fact: headline,
            care: subtitle,
            footnote: "\(recordCount) 笔 · 这一周",
            tags: ["#\(recordCount)笔记录", "#刚开头", "#周记摘页"]
        )
        self.isPetMode = isPetMode
        self.nickname = nickname
    }

    init(payload: WeeklyShareCardPayload, isPetMode: Bool = true, nickname: String = "叙账用户") {
        self.init(
            weekTotal: payload.weekTotal,
            topCategory: payload.topCategory,
            recordCount: payload.recordCount,
            primaryMetricCount: payload.primaryMetricCount,
            primaryMetricEmoji: payload.primaryMetricEmoji,
            dailyTrend: payload.dailyTrend,
            dailyCountTrend: payload.dailyCountTrend,
            categorySlices: payload.categorySlices,
            topCategoryRatio: payload.topCategoryRatio,
            headline: payload.headline,
            subtitle: payload.subtitle,
            anchorLine: payload.anchorLine,
            periodText: payload.periodText,
            insight: payload.insight,
            isPetMode: isPetMode,
            nickname: nickname
        )
    }

    private static func defaultPeriodText() -> String {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -6, to: Date()) else { return "" }
        let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd"
        return "\(f.string(from: start)) ~ \(f.string(from: Date()))"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [t.bgStart, t.bgMid, t.bgEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            paperStack
                .padding(.horizontal, 22)
                .padding(.vertical, 18)

            lowerPaperTexture
                .padding(.horizontal, 26)
                .padding(.bottom, 20)
                .frame(maxHeight: .infinity, alignment: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                weeklyCardHeader

                Text(shareHeadline)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(t.textMain)
                    .lineSpacing(5)
                    .lineLimit(3)
                    .minimumScaleFactor(0.66)
                    .padding(.top, 34)
                    .frame(minHeight: 92, alignment: .topLeading)

                weeklyChartPanel
                    .padding(.top, 8)

                Text(insight.care)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(t.textMain.opacity(0.82))
                    .lineSpacing(4)
                    .lineLimit(3)
                    .minimumScaleFactor(0.74)
                    .padding(.top, 16)

                Text(insight.footnote)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(t.textMuted.opacity(0.86))
                    .padding(.top, 5)

                weeklyMetricRow
                    .padding(.top, 12)

                rhythmTexture
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                
                shareTags
                    .padding(.bottom, 10)

                Spacer(minLength: 12)

                HStack(alignment: .center, spacing: 10) {
                    Text("叙账 · 基于你这周的真实记录")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(t.footerSub)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    shareSeal
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 42)
            .padding(.top, 38)
            .padding(.bottom, 22)
        }
        .frame(width: 390, height: 580)
        .clipped()
    }

    private var weeklyCardHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("『生活档案』· 这一周的手札")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(t.textMain.opacity(0.88))
                Text(periodText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(t.titleSub.opacity(0.86))
                    .lineLimit(1)
            }
            Spacer()
            Text("叙账")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(t.accentDeep.opacity(0.72))
        }
    }

    private var shareHeadline: String {
        let fact = insight.fact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fact.isEmpty else { return "这一周，留下了 \(recordCount) 笔记录" }
        if fact.contains("周") { return fact }
        return "这一周，\(fact)"
    }

    private var displayCategorySlices: [WeeklyShareCategorySlice] {
        if !categorySlices.isEmpty { return categorySlices }
        return [
            WeeklyShareCategorySlice(
                label: topCategory,
                count: max(primaryMetricCount, recordCount),
                ratio: min(max(topCategoryRatio, 0.12), 1)
            )
        ]
    }

    private func donutStart(at index: Int) -> Double {
        guard index > 0 else { return 0 }
        return min(displayCategorySlices.prefix(index).reduce(0) { $0 + max($1.ratio, 0) }, 1)
    }

    private func donutEnd(at index: Int) -> Double {
        guard index < displayCategorySlices.count else { return 1 }
        let end = donutStart(at: index) + max(displayCategorySlices[index].ratio, 0)
        return min(max(end, 0.04), 1)
    }

    private func donutColor(at index: Int) -> Color {
        switch index {
        case 0:
            return t.accentDeep.opacity(0.78)
        case 1:
            return t.accent.opacity(0.70)
        case 2:
            return Color(hex: "f1cf89").opacity(0.88)
        default:
            return Color(hex: "eda76f").opacity(0.82)
        }
    }

    private var weeklyChartPanel: some View {
        HStack(spacing: 18) {
            weeklyBarChart
                .frame(maxWidth: .infinity)
            weeklyDonutLegend
                .frame(width: 118)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(height: 88)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(t.panelBorder.opacity(0.74), lineWidth: 1)
        )
    }

    private var weeklyBarChart: some View {
        let maxValue = max(dailyCountTrend.map(\.1).max() ?? 0, 1)
        return ZStack(alignment: .bottomLeading) {
            VStack(spacing: 13) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle()
                        .fill(t.panelBorder.opacity(0.42))
                        .frame(height: 1)
                }
            }
            .padding(.bottom, 16)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(dailyCountTrend.prefix(7).enumerated()), id: \.offset) { _, point in
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [t.accent.opacity(0.86), t.accentDeep.opacity(0.72)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 11, height: max(8, CGFloat(point.1) / CGFloat(maxValue) * 40))
                        Text(shortWeekday(point.0))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(t.textMuted.opacity(0.76))
                            .frame(width: 14)
                    }
                }
            }
        }
    }

    private var weeklyDonutLegend: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(t.panelBorder.opacity(0.55), lineWidth: 13)
                ForEach(Array(displayCategorySlices.enumerated()), id: \.offset) { index, _ in
                    Circle()
                        .trim(from: donutStart(at: index), to: donutEnd(at: index))
                        .stroke(
                            donutColor(at: index),
                            style: StrokeStyle(lineWidth: 13, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(displayCategorySlices.enumerated()), id: \.offset) { index, slice in
                    legendRow(color: donutColor(at: index), text: slice.label)
                }
            }
        }
    }

    private func legendRow(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(t.textMain.opacity(0.84))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private var weeklyMetricRow: some View {
        HStack(spacing: 14) {
            metricSparkline(emoji: primaryMetricEmoji, value: "\(primaryMetricCount)笔", fill: t.accentDeep.opacity(0.18))
            Divider()
                .frame(height: 34)
                .overlay(t.panelBorder.opacity(0.70))
            metricSparkline(emoji: "🗓️", value: "\(activeRecordDays)天", fill: Color(hex: "dce9df").opacity(0.60))
        }
    }

    private func metricSparkline(emoji: String, value: String, fill: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Text(emoji)
                    .font(.system(size: 14))
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(t.textMain)
            }
            sparkline(fill: fill)
                .frame(height: 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sparkline(fill: Color) -> some View {
        ZStack(alignment: .bottom) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 16))
                path.addCurve(to: CGPoint(x: 54, y: 11), control1: CGPoint(x: 18, y: 8), control2: CGPoint(x: 34, y: 20))
                path.addCurve(to: CGPoint(x: 104, y: 10), control1: CGPoint(x: 72, y: 0), control2: CGPoint(x: 82, y: 25))
            }
            .stroke(t.accentDeep.opacity(0.62), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            LinearGradient(
                colors: [fill, Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var activeRecordDays: Int {
        max(1, dailyCountTrend.filter { $0.1 > 0 }.count)
    }

    private func shortWeekday(_ raw: String) -> String {
        if raw.contains("一") { return "一" }
        if raw.contains("二") { return "二" }
        if raw.contains("三") { return "三" }
        if raw.contains("四") { return "四" }
        if raw.contains("五") { return "五" }
        if raw.contains("六") { return "六" }
        if raw.contains("日") || raw.contains("天") { return "日" }
        return String(raw.suffix(1))
    }

    private var paperStack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(t.paperEdge.opacity(0.54))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(t.panelBorder.opacity(0.28), lineWidth: 1)
                )
                .rotationEffect(.degrees(-3.0))
                .offset(x: -18, y: 24)
                .shadow(color: t.paperShadow.opacity(0.10), radius: 18, x: 0, y: 10)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "f5f7ed").opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.50), lineWidth: 1)
                )
                .rotationEffect(.degrees(2.4))
                .offset(x: 17, y: 16)
                .shadow(color: t.paperShadow.opacity(0.09), radius: 16, x: 0, y: 8)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "fbfbf0").opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(t.panelBorder.opacity(0.24), lineWidth: 1)
                )
                .rotationEffect(.degrees(-0.8))
                .offset(x: -7, y: 8)
                .shadow(color: t.paperShadow.opacity(0.08), radius: 14, x: 0, y: 7)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(t.panelBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(t.panelBorder.opacity(0.72), lineWidth: 1)
                )
                .shadow(color: t.paperShadow.opacity(0.16), radius: 26, x: 0, y: 16)
        }
    }

    private var rhythmTexture: some View {
        HStack(spacing: 8) {
            ForEach(Array(dailyCountTrend.enumerated()), id: \.offset) { idx, pt in
                Circle()
                    .fill(t.accent.opacity(pt.1 > 0 ? 0.40 : 0.13))
                    .frame(width: pt.1 > 0 ? 8 : 5, height: pt.1 > 0 ? 8 : 5)
                    .accessibilityLabel("\(idx)")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
    }

    private var shareTags: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(tagRows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 7) {
                    ForEach(Array(row.enumerated()), id: \.element) { columnIndex, tag in
                        shareTagPill(tag, row: rowIndex, column: columnIndex)
                    }
                }
                .offset(x: rowIndex == 0 ? 0 : 6, y: rowIndex == 0 ? 0 : -1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shareTagPill(_ tag: String, row: Int, column: Int) -> some View {
        Text(tag)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(t.accentDeep.opacity(0.72))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.38))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(t.accent.opacity(0.24), lineWidth: 0.8)
            )
            .rotationEffect(.degrees(tagAngle(row: row, column: column)))
            .offset(y: (row + column).isMultiple(of: 2) ? 0 : 1)
    }

    private func tagAngle(row: Int, column: Int) -> Double {
        let angles: [[Double]] = [
            [-3.2, 2.0],
            [2.6, -2.2]
        ]
        guard row < angles.count, column < angles[row].count else { return 0 }
        return angles[row][column]
    }

    private var tagRows: [[String]] {
        let tags = Array(insight.tags.prefix(4))
        guard tags.count > 2 else { return [tags] }
        return [Array(tags.prefix(2)), Array(tags.dropFirst(2))]
    }

    private var lowerPaperTexture: some View {
        ZStack(alignment: .bottomLeading) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 62))
                path.addCurve(
                    to: CGPoint(x: 336, y: 48),
                    control1: CGPoint(x: 96, y: 18),
                    control2: CGPoint(x: 198, y: 86)
                )
                path.addLine(to: CGPoint(x: 336, y: 116))
                path.addLine(to: CGPoint(x: 0, y: 116))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [t.accent.opacity(0.18), Color(hex: "eef6e7").opacity(0.46), Color(hex: "fff3df").opacity(0.18)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            Path { path in
                path.move(to: CGPoint(x: 0, y: 58))
                path.addCurve(
                    to: CGPoint(x: 336, y: 44),
                    control1: CGPoint(x: 92, y: 14),
                    control2: CGPoint(x: 210, y: 76)
                )
            }
            .stroke(t.accent.opacity(0.24), lineWidth: 1)

            ForEach(0..<9, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                    .fill(t.accentDeep.opacity(idx.isMultiple(of: 2) ? 0.08 : 0.05))
                    .frame(width: CGFloat(18 + (idx % 3) * 10), height: 2)
                    .offset(x: CGFloat(18 + idx * 32), y: CGFloat(72 + (idx % 3) * 9))
            }
        }
        .frame(height: 118)
        .allowsHitTesting(false)
    }

    private var shareSeal: some View {
        ZStack {
            Circle()
                .stroke(t.accentDeep.opacity(0.20), lineWidth: 1)
            Circle()
                .stroke(t.accentDeep.opacity(0.10), lineWidth: 4)
                .padding(5)
            Text("真实\n周记")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(t.accentDeep.opacity(0.45))
                .lineSpacing(1)
        }
        .frame(width: 42, height: 42)
        .rotationEffect(.degrees(9))
        .accessibilityHidden(true)
    }

    func snapshot() -> UIImage? {
        let size = CGSize(width: 390, height: 580)
        let host = UIHostingController(rootView: self.frame(width: size.width, height: size.height))
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.backgroundColor = .clear
        let win = UIWindow(frame: CGRect(origin: .zero, size: size))
        win.rootViewController = host
        win.isHidden = false
        win.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 3.0
        let renderer = UIGraphicsImageRenderer(size: size, format: fmt)
        let img = renderer.image { _ in
            host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        win.isHidden = true
        return img
    }
}

// Color hex helper
extension Color {
    init(hex: String) {
        let r, g, b: Double
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var n: UInt64 = 0; Scanner(string: s).scanHexInt64(&n)
        r = Double((n >> 16) & 0xFF) / 255.0
        g = Double((n >> 8) & 0xFF) / 255.0
        b = Double(n & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
