import SwiftUI
import UIKit

// MARK: - Insight View

struct InsightWebView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    var onNavigateSettings: (() -> Void)? = nil
    var onShowMemberPricing: (() -> Void)? = nil
    var onOpenAppearanceSettings: (() -> Void)? = nil
    @State private var monthlyInsightGenerated = false
    @State private var showAdvancedInsight = false
    @State private var monthlyTrialUsed = UserDefaults.standard.integer(forKey: "monthly_trial_used_v1")
    @State private var monthlyReport: HomeViewModel.MonthlyInsightReport?
    @State private var monthlyAIStatus: AIStatusPill?
    @State private var monthlyTrialModal: MonthlyTrialModal?
    @State private var isSavingWeeklyShareCard = false
    @State private var weeklyShareSaveMessage: String?
    @State private var showWeeklyShareThemeNudge = false
    @State private var isTodayInsightExpanded = false
    @State private var showMonthlyInsightSheet = false
    @State private var showTodayInsightSheet = false
    @State private var monthlyActionMessage: String?
    @State private var monthlyNarrativeVariant = 0
    @State private var showWeeklySharePrivacyConfirm = false
    @State private var showAICommandSheet = false
    @State private var aiCommandText = ""
    @State private var aiCommandAmountText = ""
    @State private var aiCommandResult: AICommandResult?
    @State private var aiCommandMessage: String?
    @State private var aiCommandSavedCount: Int?
    private let trialTotal = 5
    private static var aiCommandSuggestionsCache: [String: [String]] = [:]
    private static var aiCommandItemsCache: [String: [HomeItem]] = [:]
    private static var aiCommandLifeMarkItemsCache: [String: [HomeItem]] = [:]
    private static var aiCommandCacheOrder: [String] = []
    private static let aiCommandCacheLimit = 48
    private static let mainlandChinaHolidayOverrides: Set<String> = [
        "2026-06-19" // Dragon Boat Festival holiday.
    ]

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

    private enum AICommandKind: Equatable {
        case query
        case memoryLookup
        case duplicateCheck
        case batchCreate
        case needsAmount
        case unsupported
    }

    private struct AICommandBar: Identifiable, Equatable {
        let id = UUID()
        var label: String
        var amount: Double
        var count: Int
    }

    private struct AICommandMemoryCard: Identifiable, Equatable {
        let id = UUID()
        var title: String
        var subtitle: String
        var item: HomeItem
        var context: HomeItem.MemoryContext?
    }

    private struct AICommandResult: Identifiable, Equatable {
        let id = UUID()
        var kind: AICommandKind
        var title: String
        var summary: String
        var detail: String
        var items: [HomeItem]
        var memoryCard: AICommandMemoryCard? = nil
        var bars: [AICommandBar]
        var drafts: [AICommandRecordDraft]
        var amountSource: String?
        var needsAmount: Bool
    }

    private struct AICommandTimeRange: Equatable {
        var label: String
        var start: Date
        var end: Date
        var barDays: Int
        var isFallback: Bool = false

        func contains(_ date: Date) -> Bool {
            date >= start && date < end
        }
    }

    private struct AICommandCategoryIntent: Equatable {
        var categories: [HomeItem.Category]
        var label: String
        var keywords: [String]
        var requiresKeywordMatch: Bool = false
    }

    private struct AICommandDuplicateGroup: Identifiable, Equatable {
        let id: String
        var items: [HomeItem]
        var score: Int
        var reason: String
    }

    private struct AICommandInputPanelView: View {
        @Binding var commandText: String
        let onRun: (String) -> Void
        let onClear: () -> Void
        @State private var draftText: String
        @FocusState private var isFocused: Bool

        init(commandText: Binding<String>, onRun: @escaping (String) -> Void, onClear: @escaping () -> Void) {
            _commandText = commandText
            self.onRun = onRun
            self.onClear = onClear
            _draftText = State(initialValue: commandText.wrappedValue)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("你想让它做什么？")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.text.opacity(0.86))

                TextField("例如：帮我看一下过去三天餐饮类的消费", text: $draftText, axis: .vertical)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(2...4)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(.done)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.62))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.64), lineWidth: 1)
                    )
                    .onChange(of: commandText) { _, value in
                        guard value != draftText else { return }
                        draftText = value
                    }
                    .onSubmit {
                        isFocused = false
                    }

                HStack(spacing: 10) {
                    Button {
                        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
                        commandText = trimmed
                        isFocused = false
                        onRun(trimmed)
                    } label: {
                        aiCommandPrimaryLabel("生成预览", systemImage: "sparkles")
                    }
                    .buttonStyle(.plain)

                    Button {
                        draftText = ""
                        commandText = ""
                        isFocused = false
                        onClear()
                    } label: {
                        Text("清空")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.subtext)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.46))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .glassPanel(radius: 22, padding: 18)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        isFocused = false
                    }
                }
            }
        }

        private func aiCommandPrimaryLabel(_ title: String, systemImage: String) -> some View {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.94), AppColors.accentDark.opacity(0.94)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: AppColors.accent.opacity(0.18), radius: 10, x: 0, y: 5)
        }
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
        .sheet(isPresented: $showAICommandSheet) {
            aiCommandSheet
        }
    }

    private var insightContent: some View {
        let weeklyBlocks = homeViewModel.localWeeklyInsightBlocks()
        let weekItems = recentPositiveItems(days: 7)
        let keywords = weeklyKeywordBubbles(from: flexibleBubblePositiveItems)

        return VStack(alignment: .leading, spacing: 0) {
            insightJournalCard(weeklyBlocks: weeklyBlocks, weekItems: weekItems)
            insightChapterFootnote
            keywordBubbleSection(keywords: keywords)
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

    @ViewBuilder
    private var weeklyShareThemeNudge: some View {
        if showWeeklyShareThemeNudge {
            Button {
                showWeeklyShareThemeNudge = false
                onOpenAppearanceSettings?()
            } label: {
                Text("用典藏主题导出分享图 →")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.accentDark.opacity(0.82))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private var shouldShowWeeklyShareThemeNudge: Bool {
        guard settingsViewModel.memberTier.lowercased() != "lifetime" else { return false }
        return !Self.permanentThemeIds.contains(settingsViewModel.colorThemeId)
    }

    private static let permanentThemeIds: Set<String> = [
        "lifetime_archive_gold",
        "lifetime_gilded_circuit",
        "lifetime_neon_cathedral"
    ]

    private var insightJournalCard: some View {
        insightJournalCard(
            weeklyBlocks: homeViewModel.localWeeklyInsightBlocks(),
            weekItems: recentPositiveItems(days: 7)
        )
    }

    private func insightJournalCard(
        weeklyBlocks: (summary: String, structure: String, advice: String),
        weekItems: [HomeItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(weekKickerText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.subtext.opacity(0.78))

            Text(formatWeeklyJournalText(weeklyBlocks, weekItems: weekItems))
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

            HStack(spacing: 8) {
                quietTextButton("保存周记摘页") {
                    showWeeklySharePrivacyConfirm = true
                }

                quietTextButton("让 AI 继续解读 →") {
                    openWeeklyAICommand()
                }
            }
            .padding(.top, 2)

            if let weeklyShareSaveMessage {
                Text(weeklyShareSaveMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                weeklyShareThemeNudge
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

    private func openWeeklyAICommand() {
        showAICommandSheet = true
        if aiCommandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            aiCommandText = "帮我继续解读最近这段生活，看看生活节奏、压力变化和最值得保留的瞬间。"
        }
    }

    @ViewBuilder
    private var keywordBubbleSection: some View {
        keywordBubbleSection(keywords: weeklyKeywordBubbles())
    }

    @ViewBuilder
    private func keywordBubbleSection(keywords: [KeywordBubbleData]) -> some View {
        if keywords.count >= 3 {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近的碎碎念")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.text.opacity(0.88))
                    Text("以本周为主；有新的生活印记，也会直接冒出来。")
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

    private func formatWeeklyJournalText(
        _ blocks: (summary: String, structure: String, advice: String),
        weekItems providedWeekItems: [HomeItem]? = nil
    ) -> String {
        if blocks.summary.contains("暂无复盘") {
            return "近 7 天记录还不多。多记几笔，这里会整理成一段周记。"
        }
        let weekItems = providedWeekItems ?? recentPositiveItems(days: 7)
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

    private var currentWeekPositiveItems: [HomeItem] {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return recentPositiveItems(days: 7)
        }
        return homeViewModel.items.filter {
            $0.createdAt >= interval.start && $0.createdAt < interval.end && $0.amount > 0
        }
    }

    private var flexibleBubblePositiveItems: [HomeItem] {
        let recentCutoff = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let weekIDs = Set(currentWeekPositiveItems.map(\.id))
        let recentlyTouched = homeViewModel.items.filter {
            $0.amount > 0 && $0.updatedAt >= recentCutoff && !weekIDs.contains($0.id)
        }
        return currentWeekPositiveItems + recentlyTouched
    }

    private func weeklyKeywordBubbles() -> [KeywordBubbleData] {
        weeklyKeywordBubbles(from: flexibleBubblePositiveItems)
    }

    private func weeklyKeywordBubbles(from items: [HomeItem]) -> [KeywordBubbleData] {
        guard !items.isEmpty else { return [] }

        let targetCount: Int
        if items.count >= 5 {
            targetCount = 6
        } else if items.count >= 3 {
            targetCount = 3
        } else {
            return []
        }

        let candidates = weeklyBubbleCandidates(from: items)
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

    private func weeklyBubbleCandidates(from items: [HomeItem]) -> [KeywordBubbleDraft] {
        var candidates = weeklyLifeMarkBubbleCandidates(from: items)
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

        for item in items where item.id != heroID {
            if let context = item.memoryContext {
                if context.weatherKind == "rain" {
                    let text: String
                    if item.category == .transport {
                        text = "雨天出行"
                    } else if let city = context.cityName, context.semanticPlace == "外地" {
                        text = "\(city)雨天"
                    } else {
                        text = "雨天生活"
                    }
                    candidates.append(
                        KeywordBubbleDraft(
                            text: text,
                            score: 3_200 + Int(item.amount.rounded()) + (context.semanticPlace == "外地" ? 420 : 0),
                            category: item.category,
                            priority: 2,
                            source: .context
                        )
                    )
                }
                if let city = context.cityName, context.semanticPlace == "外地" {
                    candidates.append(
                        KeywordBubbleDraft(
                            text: "\(city)一日",
                            score: 2_800 + Int(item.amount.rounded()),
                            category: item.category,
                            priority: 3,
                            source: .context
                        )
                    )
                }
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

    private func weeklyLifeMarkBubbleCandidates(from items: [HomeItem]) -> [KeywordBubbleDraft] {
        LifeMarkService.aggregates(
            for: items,
            allItems: homeViewModel.items,
            isMember: true,
            now: Date(),
            limit: 6
        ).compactMap { mark in
            guard let text = bubbleText(for: mark) else { return nil }
            return KeywordBubbleDraft(
                text: text,
                score: 9_200 + lifeMarkBubbleScoreBoost(mark) + mark.count * 180,
                category: mark.category,
                priority: lifeMarkBubblePriority(mark),
                source: .lifeMark
            )
        }
    }

    private func bubbleText(for mark: LifeMarkAggregate) -> String? {
        let raw: String
        switch mark.kind {
        case .milestone:
            raw = mark.title
        case .context, .scene:
            raw = mark.label
        case .streak:
            raw = mark.label.hasPrefix("连续")
                ? "一段\(mark.label.replacingOccurrences(of: "连续", with: ""))节奏"
                : mark.label
        }
        let text = normalizedKeyword(raw, maxLength: 12)
        return text.isEmpty ? nil : text
    }

    private func lifeMarkBubblePriority(_ mark: LifeMarkAggregate) -> Int {
        switch mark.kind {
        case .milestone:
            return 0
        case .context:
            return 1
        case .scene:
            return 2
        case .streak:
            return 4
        }
    }

    private func lifeMarkBubbleScoreBoost(_ mark: LifeMarkAggregate) -> Int {
        switch mark.kind {
        case .milestone:
            return 1_400
        case .context:
            return 900
        case .scene:
            return 650
        case .streak:
            return 260
        }
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
                   candidate.source != .userTitle,
                   candidate.source != .lifeMark {
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

        let candidates = ["咖啡", "奶茶", "早餐", "午餐", "晚餐", "夜宵", "七欣天", "外卖", "食堂", "热饭", "打车", "地铁", "公交", "停车", "充电", "超市", "便利店", "买菜", "小象", "京东到家", "水果", "药", "运动", "健身", "奶粉", "尿不湿", "狗粮", "猫粮", "宠物", "酒店", "民宿", "旅行", "电影", "渔具", "露营", "摄影", "手办"]
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
                weeklyShareThemeNudge
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

    private var aiCommandSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.bg.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        aiCommandSheetHeader
                        aiCommandInputPanel
                        aiCommandSuggestionRow
                        if let aiCommandMessage {
                            Text(aiCommandMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppColors.subtext)
                                .padding(.horizontal, 4)
                        }
                        aiCommandResultPanel
                    }
                    .padding(18)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("AI 指令台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismissKeyboard()
                        showAICommandSheet = false
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.accentDark)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var aiCommandSheetHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.12))
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.accentDark)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text("把账本里的事交代清楚")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.text)
                    Text("先理解、再预览；涉及新增记录时，确认后才会保存。")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.subtext)
                }
            }
        }
        .paperChapterPanel(radius: 22, padding: 18, showsAccentLine: false)
    }

    private var aiCommandInputPanel: some View {
        AICommandInputPanelView(
            commandText: $aiCommandText,
            onRun: { runAICommand($0) },
            onClear: clearAICommandInput
        )
    }

    private var aiCommandSuggestionRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(aiCommandPresetSuggestions(), id: \.self) { suggestion in
                    aiCommandPresetChip(suggestion)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func aiCommandPresetSuggestions() -> [String] {
        let cacheKey = aiCommandSuggestionsCacheKey()
        if let cached = Self.aiCommandSuggestionsCache[cacheKey] {
            return cached
        }

        var suggestions: [String] = []
        var lockedPreviewSuggestions: [String] = []
        let recentItems = recentPositiveItems(days: 7)
        let todayWeatherKind = RecordMemoryContextService.weatherKindCode(
            from: WeatherCompanionService.shared.cachedSnapshot
        )
        let hasRainToday = todayWeatherKind == "rain" || recentItems.contains { item in
            Calendar.current.isDateInToday(item.createdAt) && item.memoryContext?.weatherKind == "rain"
        }

        if hasRainToday {
            if hasMemberAccess {
                suggestions.append("上一次雨天通勤是什么时候？")
            } else {
                lockedPreviewSuggestions.append("上一次雨天通勤是什么时候？")
            }
        }
        if recentItems.contains(where: { $0.category == .dining }) {
            suggestions.append("过去三天餐饮花了多少？")
        }
        if recentItems.contains(where: { $0.category == .transport }) {
            suggestions.append("看一下这周交通")
        }
        if recentItems.contains(where: { $0.category == .entertainment }) {
            suggestions.append("上周休闲娱乐花了多少钱？")
        }
        let recentMarks = LifeMarkService.aggregates(
            for: recentItems,
            allItems: homeViewModel.items,
            isMember: hasMemberAccess,
            limit: 3
        )
        suggestions.append(contentsOf: recentMarks.map(\.queryHint))
        if recentItems.contains(where: { $0.source == .ocr || $0.draftMeta != nil }) {
            suggestions.append("找找最近有没有重复账单")
        }
        if shouldSuggestCommuteDraft(recentItems: recentItems) {
            suggestions.append("补记过去一周工作日通勤，早晚各一次")
        }

        let fallback = ["过去三天餐饮花了多少？", "看一下这周交通", "找找最近有没有重复账单"]
        let result = Array(uniqueAICommandSuggestions(suggestions + fallback + lockedPreviewSuggestions).prefix(5))
        storeAICommandSuggestions(result, for: cacheKey)
        return result
    }

    private func uniqueAICommandSuggestions(_ suggestions: [String]) -> [String] {
        var seen = Set<String>()
        return suggestions.filter { suggestion in
            if seen.contains(suggestion) { return false }
            seen.insert(suggestion)
            return true
        }
    }

    private func aiCommandSuggestionsCacheKey() -> String {
        let weatherKind = RecordMemoryContextService.weatherKindCode(
            from: WeatherCompanionService.shared.cachedSnapshot
        ) ?? "none"
        return [
            "suggestions",
            hasMemberAccess ? "member" : "free",
            weatherKind,
            aiCommandItemsSignature(homeViewModel.items)
        ].joined(separator: "|")
    }

    private func storeAICommandSuggestions(_ suggestions: [String], for key: String) {
        guard Self.aiCommandSuggestionsCache[key] == nil else {
            return
        }
        Self.aiCommandSuggestionsCache[key] = suggestions
        rememberAICommandCacheKey("suggestions|\(key)")
    }

    private func shouldSuggestCommuteDraft(recentItems: [HomeItem]) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        guard weekday >= 2 && weekday <= 6 else { return false }
        let commuteCount = recentItems.filter { item in
            guard item.category == .transport else { return false }
            let text = "\(item.title) \(item.displayEmotionTag)"
            return containsAny(text, ["通勤", "上班", "下班", "地铁", "公交"]) || item.amount <= 20
        }.count
        return commuteCount >= 2
    }

    private func aiCommandPresetChip(_ title: String) -> some View {
        Button {
            dismissKeyboard()
            aiCommandText = title
            runAICommand(title)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext)
                .lineLimit(1)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.56))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.52), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var aiCommandResultPanel: some View {
        if let result = aiCommandResult {
            LazyVStack(alignment: .leading, spacing: 14) {
                aiCommandIntentCard(result)
                if let memoryCard = result.memoryCard {
                    aiCommandMemoryCard(memoryCard)
                }
                if !result.bars.isEmpty {
                    aiCommandBarChart(result.bars)
                }
                if !result.items.isEmpty {
                    aiCommandItemsPreview(result.items)
                }
                if result.needsAmount {
                    aiCommandAmountInput(result)
                }
                if !result.drafts.isEmpty {
                    aiCommandDraftPreview(result)
                }
                aiCommandResultActions(result)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("可以先从一个小问题开始")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Text("比如查一段时间的餐饮、交通，或者让它先生成一批待确认的通勤记录。")
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(AppColors.subtext)
            }
            .glassPanel(radius: 20, padding: 18)
        }
    }

    private func aiCommandIntentCard(_ result: AICommandResult) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text("我理解的是")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.subtext)
                Spacer()
                Text(aiCommandKindText(result.kind))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(result.kind == .batchCreate ? AppColors.lockGold : AppColors.accentDark)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill((result.kind == .batchCreate ? AppColors.lockGold : AppColors.accent).opacity(0.10))
                    )
            }

            Text(result.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(result.summary)
                .font(.system(size: 14, weight: .medium))
                .lineSpacing(4)
                .foregroundStyle(AppColors.text.opacity(0.84))

            if !result.detail.isEmpty {
                Text(result.detail)
                    .font(.system(size: 12))
                    .lineSpacing(3)
                    .foregroundStyle(AppColors.subtext)
            }
        }
        .glassPanel(radius: 22, padding: 18)
    }

    private func aiCommandMemoryCard(_ card: AICommandMemoryCard) -> some View {
        let isRain = card.context?.weatherKind == "rain"
        let contextLine = aiCommandMemoryContextLine(card.context)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill((isRain ? Color(red: 0.42, green: 0.58, blue: 0.66) : AppColors.accent).opacity(0.14))
                    Image(systemName: isRain ? "cloud.rain.fill" : "sparkles")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isRain ? Color(red: 0.34, green: 0.50, blue: 0.58) : AppColors.accentDark)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.text)
                    Text(card.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(card.item.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.text.opacity(0.92))
                    .lineLimit(2)
                Text("\(card.item.category.rawValue) · \(card.item.createdAt.zhBillDateOnly) · \(card.item.amount.formatted(.cny))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                if !contextLine.isEmpty {
                    Text(contextLine)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.text.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if shouldShowHomeEmotionLike(card.item) {
                    Text(card.item.displayEmotionTag)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isRain ? Color(red: 0.30, green: 0.48, blue: 0.56) : AppColors.accentDark)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(isRain ? Color(red: 0.76, green: 0.84, blue: 0.88).opacity(0.54) : Color.white.opacity(0.54))
                        if isRain {
                            WeatherMemoryBackdrop(kind: .rain)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    }
                )
                .overlay(
                    ZStack {
                        LinearGradient(
                            colors: isRain
                                ? [
                                    Color.white.opacity(0.74),
                                    Color(red: 0.62, green: 0.76, blue: 0.82).opacity(0.26),
                                    Color(red: 0.36, green: 0.54, blue: 0.62).opacity(0.16)
                                ]
                                : [
                                    Color.white.opacity(0.70),
                                    Color.white.opacity(0.42),
                                    AppColors.accent.opacity(0.12)
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        if isRain {
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.04),
                                    Color(red: 0.30, green: 0.45, blue: 0.54).opacity(0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                )
                .overlay(alignment: .topTrailing) {
                    if isRain {
                        Image(systemName: "cloud.rain")
                            .font(.system(size: 78, weight: .ultraLight))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.white.opacity(0.24))
                            .offset(x: 12, y: -8)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.78),
                                    Color.white.opacity(isRain ? 0.28 : 0.42),
                                    (isRain ? Color(red: 0.36, green: 0.54, blue: 0.62) : AppColors.accent).opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private func aiCommandBarChart(_ bars: [AICommandBar]) -> some View {
        let maxAmount = max(bars.map(\.amount).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("简图")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.subtext)

            HStack(alignment: .bottom, spacing: 9) {
                ForEach(bars) { bar in
                    VStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.accent.opacity(0.86), AppColors.paperMist.opacity(0.72)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: CGFloat(max(8, min(82, (bar.amount / maxAmount) * 82))))
                            .overlay(alignment: .top) {
                                if bar.count > 0 {
                                    Text("\(bar.count)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.92))
                                        .padding(.top, 4)
                                }
                            }
                        Text(bar.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppColors.subtext)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
        }
        .glassPanel(radius: 20, padding: 16)
    }

    private func aiCommandItemsPreview(_ items: [HomeItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("相关记录")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.subtext)
                Spacer()
                Text("\(items.count) 笔")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
            }

            ForEach(items.prefix(8)) { item in
                aiCommandItemRow(item)
            }
        }
        .glassPanel(radius: 20, padding: 16)
    }

    private func aiCommandItemRow(_ item: HomeItem) -> some View {
        HStack(spacing: 10) {
            Text(item.category.emoji)
                .font(.system(size: 15))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(AppColors.accent.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                Text(item.createdAt.zhBillDateTime)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.subtext)
                Text(item.source.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.72))
            }

            Spacer(minLength: 8)

            Text(item.amount.formatted(.cny))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.86))
        }
        .padding(.vertical, 7)
    }

    private func aiCommandAmountInput(_ result: AICommandResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还差一个金额")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.text)
            Text("没有找到最近的通勤金额。填一个单程金额后，我再生成待确认列表。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)

            HStack(spacing: 10) {
                TextField("单程金额", text: $aiCommandAmountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color.white.opacity(0.58))
                    )

                Button {
                    runAICommand(aiCommandText)
                } label: {
                    aiCommandPrimaryLabel("生成", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.plain)
            }
        }
        .glassPanel(radius: 20, padding: 16)
    }

    private func aiCommandDraftPreview(_ result: AICommandResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("待确认记录")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.subtext)
                Spacer()
                if let amountSource = result.amountSource {
                    Text(amountSource)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                }
            }

            ForEach(result.drafts.prefix(12)) { draft in
                aiCommandDraftRow(draft)
            }
        }
        .glassPanel(radius: 20, padding: 16)
    }

    private func aiCommandDraftRow(_ draft: AICommandRecordDraft) -> some View {
        let isConflict: Bool = {
            if case .conflict = draft.status { return true }
            return false
        }()
        return HStack(spacing: 10) {
            Image(systemName: isConflict ? "exclamationmark.triangle.fill" : "plus.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isConflict ? AppColors.lockGold.opacity(0.95) : AppColors.accentDark.opacity(0.86))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill((isConflict ? AppColors.lockGold : AppColors.accent).opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(draft.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.text)
                Text(draft.date.zhBillDateTime)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.subtext)
                if case let .conflict(message) = draft.status {
                    Text(message)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "8B6F38"))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            Text(draft.amount.formatted(.cny))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.86))
        }
        .padding(.vertical, 7)
        .padding(.horizontal, isConflict ? 9 : 0)
        .background {
            if isConflict {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.lockGold.opacity(0.10))
            }
        }
    }

    @ViewBuilder
    private func aiCommandResultActions(_ result: AICommandResult) -> some View {
        if result.kind == .unsupported {
            EmptyView()
        } else if result.kind == .needsAmount {
            EmptyView()
        } else if !result.drafts.isEmpty {
            let saveableDrafts = result.drafts.filter { draft in
                if case .conflict = draft.status { return false }
                return draft.amount > 0
            }
            VStack(alignment: .leading, spacing: 9) {
                Button {
                    saveAICommandDrafts(saveableDrafts)
                } label: {
                    aiCommandPrimaryLabel(
                        hasMemberAccess ? "确认保存 \(saveableDrafts.count) 条" : "开通会员保存全部",
                        systemImage: hasMemberAccess ? "checkmark.circle.fill" : "lock.fill"
                    )
                }
                .buttonStyle(.plain)
                .disabled(saveableDrafts.isEmpty && hasMemberAccess)
                .opacity(saveableDrafts.isEmpty && hasMemberAccess ? 0.52 : 1)

                if let aiCommandSavedCount {
                    Text("已保存 \(aiCommandSavedCount) 条到账本。")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                } else if saveableDrafts.count < result.drafts.count {
                    Text("高亮的记录疑似已经存在，已先排除；真要补记，可以改成单笔手动添加。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext)
                } else if !hasMemberAccess {
                    Text("查询可以先看结果；批量补记属于会员能力，避免免费用户误触生成大量记录。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext)
                }
            }
        } else {
            Button {
                    runAICommand(aiCommandText, successMessage: "已按当前指令重新整理一次。")
                } label: {
                    aiCommandSecondaryLabel("重新整理一次", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
        }
    }

    private func aiCommandPrimaryLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
            Text(title)
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.94), AppColors.accentDark.opacity(0.94)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: AppColors.accent.opacity(0.18), radius: 10, x: 0, y: 5)
    }

    private func aiCommandSecondaryLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(AppColors.subtext)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.52))
        )
    }

    private func runAICommand(_ override: String? = nil, successMessage: String? = nil) {
        let command = (override ?? aiCommandText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            aiCommandMessage = "先写一句你想让它整理什么。"
            return
        }
        aiCommandSavedCount = nil
        aiCommandMessage = nil
        aiCommandResult = buildAICommandResult(for: command)
        if let successMessage {
            withAnimation(.easeInOut(duration: 0.18)) {
                aiCommandMessage = successMessage
            }
        }
    }

    private func clearAICommandInput() {
        aiCommandAmountText = ""
        aiCommandResult = nil
        aiCommandMessage = nil
        aiCommandSavedCount = nil
    }

    private func buildAICommandResult(for command: String) -> AICommandResult {
        let normalized = command.lowercased()
        if containsAny(normalized, ["补记", "补上", "生成", "新增"]) && containsAny(normalized, ["通勤", "交通", "上班", "下班", "早晚"]) {
            return buildCommuteDraftResult(command: normalized)
        }
        if containsAny(normalized, ["重复", "重复账单", "重复记录"]) {
            return buildDuplicateCheckResult(range: aiCommandTimeRange(from: normalized, defaultRecentDays: 7))
        }
        let lifeMarkIntent = LifeMarkService.queryIntent(from: normalized)
        if let lifeMarkIntent,
           !hasMemberAccess,
           shouldRequireMemberForLifeMark(intent: lifeMarkIntent, command: normalized) {
            return buildLifeMarkLockedResult(intent: lifeMarkIntent, command: normalized)
        }
        if let memoryResult = buildMemoryLookupResult(command: normalized) {
            return memoryResult
        }
        if let lifeMarkIntent,
           containsAny(normalized, ["上一次", "上次", "最近一次", "什么时候", "哪天", "第一次", "首次", "第一笔", "第1笔", "第一条", "第1条", "第一单", "第1单", "第十次", "第10次", "10次", "十次"]) {
            return buildLifeMarkLookupResult(intent: lifeMarkIntent, command: normalized)
        }

        let range = aiCommandTimeRange(from: normalized)
        let categoryIntent = aiCommandCategoryIntent(from: normalized)
        if lifeMarkIntent != nil || categoryIntent != nil || aiCommandAsksCategoryBreakdown(normalized) || containsAny(normalized, ["查", "看", "多少", "几次", "花了", "消费", "账本", "记录", "流水", "明细", "整理", "概览", "最近", "近来", "这阵子", "这段时间", "今天", "昨日", "昨天", "本周", "这周", "这一周", "本自然周", "这个自然周", "本星期", "这个星期", "这星期", "本礼拜", "这个礼拜", "这礼拜", "上周", "上一周", "上个自然周", "上一个自然周", "上星期", "上个星期", "上礼拜", "上个礼拜", "本月", "这个月", "这月", "上个月", "上月"]) {
            return buildQueryResult(
                range: range,
                categoryIntent: categoryIntent,
                lifeMarkIntent: lifeMarkIntent,
                command: normalized
            )
        }
        return AICommandResult(
            kind: .unsupported,
            title: "这条指令还需要再具体一点",
            summary: "可以先问一段时间、一个分类，或明确说要补记哪类记录。",
            detail: "例子：过去三天餐饮花了多少？或者：补记过去一周工作日通勤，早晚各一次。",
            items: [],
            bars: [],
            drafts: [],
            amountSource: nil,
            needsAmount: false
        )
    }

    private func buildMemoryLookupResult(command: String) -> AICommandResult? {
        let asksMemory = containsAny(command, ["上一次", "上次", "最近一次", "什么时候", "哪天", "记得", "回忆", "回看"])
        let hasContextSignal = containsAny(command, ["下雨", "雨天", "雨", "雪", "外地", "城市", "旅游", "旅行", "出差", "温度", "天气"])
        guard asksMemory && hasContextSignal else { return nil }

        let item = homeViewModel.items
            .lazy
            .filter { item in
                guard item.amount > 0 else { return false }
                return aiCommandMemoryItemMatches(item, command: command)
            }
            .max { $0.createdAt < $1.createdAt }

        guard let item else {
            return AICommandResult(
                kind: .memoryLookup,
                title: "还没找到这段生活记忆",
                summary: "账本里暂时没有匹配的天气或城市线索。",
                detail: "从之后的新记录开始，天气、温度和低敏城市语义会随当天记录一起保存；历史记录如果没有这些字段，只能按备注和分类粗略查找。",
                items: [],
                bars: [],
                drafts: [],
                amountSource: nil,
                needsAmount: false
            )
        }

        let title = aiCommandMemoryTitle(command: command, item: item)
        let relatedItems = aiCommandRelatedMemoryItems(anchor: item, command: command)
        let card = AICommandMemoryCard(
            title: title,
            subtitle: item.createdAt.zhBillDateOnly,
            item: item,
            context: item.memoryContext
        )
        return AICommandResult(
            kind: .memoryLookup,
            title: title,
            summary: "找到了 \(item.createdAt.zhBillDateOnly) 的那次记录。",
            detail: aiCommandMemoryContextLine(item.memoryContext),
            items: sortedAICommandEvidenceItems(relatedItems),
            memoryCard: card,
            bars: [],
            drafts: [],
            amountSource: nil,
            needsAmount: false
        )
    }

    private func buildQueryResult(
        range: AICommandTimeRange,
        categoryIntent: AICommandCategoryIntent?,
        lifeMarkIntent: LifeMarkQueryIntent? = nil,
        command: String = ""
    ) -> AICommandResult {
        let items = lifeMarkIntent.map { filteredAICommandLifeMarkItems(range: range, intent: $0, command: command) }
            ?? filteredAICommandItems(range: range, intent: categoryIntent)
        let total = items.reduce(0) { $0 + $1.amount }
        let categoryText = aiCommandLifeMarkLabel(lifeMarkIntent, command: command) ?? categoryIntent?.label ?? "全部"
        let rangeNote = range.isFallback ? "「最近/这阵子」先按最近 7 天整理。" : "\(range.label)已整理。"
        if categoryIntent == nil, lifeMarkIntent == nil, aiCommandAsksCategoryBreakdown(command) {
            let summary: String
            if items.isEmpty {
                summary = "\(range.label)没有找到记录。"
            } else if let top = aiCommandTopCategorySummary(items) {
                summary = "\(range.label)里「\(top.category.rawValue)」最多，\(top.count) 笔，合计 \(top.total.formatted(.cny))。"
            } else {
                summary = "\(range.label)的分类还不明显。"
            }
            return AICommandResult(
                kind: .query,
                title: "\(range.label)的分类分布",
                summary: summary,
                detail: aiCommandCategoryBreakdownDetail(items: items, total: total, fallback: rangeNote),
                items: sortedAICommandEvidenceItems(items),
                bars: dailyBars(range: range, items: items),
                drafts: [],
                amountSource: nil,
                needsAmount: false
            )
        }

        let summary = items.isEmpty
            ? "\(range.label)没有找到\(categoryText)记录。"
            : "\(range.label)找到 \(items.count) 笔\(categoryText)记录，合计 \(total.formatted(.cny))。"
        let detail: String
        if let top = items.max(by: { $0.amount < $1.amount }) {
            detail = "\(rangeNote) 金额最高的是「\(top.displayTitle)」，\(top.amount.formatted(.cny))，时间在 \(top.createdAt.zhBillDateTime)。"
        } else {
            detail = "\(rangeNote) 换个范围或分类再问一次，结果会更明确。"
        }
        return AICommandResult(
            kind: .query,
            title: "\(range.label)的\(categoryText)记录",
            summary: summary,
            detail: detail,
            items: sortedAICommandEvidenceItems(items),
            bars: dailyBars(range: range, items: items),
            drafts: [],
            amountSource: nil,
            needsAmount: false
        )
    }

    private func buildLifeMarkLookupResult(
        intent: LifeMarkQueryIntent,
        command: String
    ) -> AICommandResult {
        let displayLabel = aiCommandLifeMarkLabel(intent, command: command) ?? intent.label
        let hasExplicitTimeRange = aiCommandHasExplicitTimeRange(command)
        let lookupRange = hasExplicitTimeRange ? aiCommandTimeRange(from: command, defaultRecentDays: 31) : aiCommandAllTimeRange
        let matched = filteredAICommandLifeMarkItems(
            range: lookupRange,
            intent: intent,
            command: command
        )
        .sorted { $0.createdAt < $1.createdAt }
        let target = LifeMarkService.milestoneTarget(from: command)
        let item: HomeItem?
        let title: String
        if let target {
            item = matched.count >= target ? matched[target - 1] : nil
            let prefix = hasExplicitTimeRange ? lookupRange.label : ""
            title = target == 1 ? "\(prefix)第一次\(displayLabel)" : "\(prefix)\(displayLabel)第 \(target) 次"
        } else {
            item = matched.last
            title = hasExplicitTimeRange ? "\(lookupRange.label)上一次\(displayLabel)" : "上一次\(displayLabel)"
        }

        guard let item else {
            let targetText = target.map { $0 == 1 ? "第一次" : "第 \($0) 次" } ?? "上一次"
            let rangeText = hasExplicitTimeRange ? "\(lookupRange.label)内" : "账本里"
            return AICommandResult(
                kind: .query,
                title: "还没找到\(targetText)\(displayLabel)",
                summary: "\(rangeText)暂时没有足够明确的\(displayLabel)记录。",
                detail: "之后只要备注、分类或天气城市线索匹配，这类生活印记会自动累积。",
                items: [],
                bars: [],
                drafts: [],
                amountSource: nil,
                needsAmount: false
            )
        }

        let relatedRange = hasExplicitTimeRange ? lookupRange : aiCommandTimeRange(from: command, defaultRecentDays: 31)
        let related = filteredAICommandLifeMarkItems(
            range: relatedRange,
            intent: intent,
            command: command
        )
        let contextLine = aiCommandMemoryContextLine(item.memoryContext)
        let detailParts = [
            "时间在 \(item.createdAt.zhBillDateOnly)，金额 \(item.amount.formatted(.cny))。",
            contextLine.isEmpty ? nil : contextLine
        ]
        .compactMap { $0 }
        return AICommandResult(
            kind: .query,
            title: title,
            summary: "找到了 \(item.createdAt.zhBillDateOnly) 的「\(item.displayTitle)」。",
            detail: detailParts.joined(separator: " "),
            items: sortedAICommandEvidenceItems(uniqueAICommandItems([item] + related)),
            bars: dailyBars(range: relatedRange, items: related),
            drafts: [],
            amountSource: nil,
            needsAmount: false
        )
    }

    private func shouldRequireMemberForLifeMark(
        intent: LifeMarkQueryIntent,
        command: String
    ) -> Bool {
        if LifeMarkService.access(for: intent) == .member {
            return true
        }
        if LifeMarkService.milestoneTarget(from: command) != nil {
            return true
        }
        return containsAny(command, ["连续", "连着", "第几次", "第几回"])
    }

    private func buildLifeMarkLockedResult(
        intent: LifeMarkQueryIntent,
        command: String
    ) -> AICommandResult {
        let asksMilestone = LifeMarkService.milestoneTarget(from: command) != nil
        let displayLabel = aiCommandLifeMarkLabel(intent, command: command) ?? intent.label
        let reason = asksMilestone
            ? "首次、第十次和连续记录属于会员的深层生活印记。"
            : "天气、异地和周末相聚这类上下文印记属于会员能力。"
        return AICommandResult(
            kind: .unsupported,
            title: "会员可看「\(displayLabel)」",
            summary: reason,
            detail: "免费版先保留基础次数和金额统计；会员会把关联记录、天气城市、里程碑和连续性一起整理出来。",
            items: [],
            bars: [],
            drafts: [],
            amountSource: nil,
            needsAmount: false
        )
    }

    private func aiCommandAsksCategoryBreakdown(_ command: String) -> Bool {
        containsAny(command, ["哪一类", "哪类", "什么类", "分类", "最多", "占比", "花在哪"])
    }

    private func aiCommandTopCategorySummary(_ items: [HomeItem]) -> (category: HomeItem.Category, count: Int, total: Double)? {
        Dictionary(grouping: items, by: \.category)
            .map { category, rows in
                (category: category, count: rows.count, total: rows.reduce(0) { $0 + $1.amount })
            }
            .sorted {
                if $0.count == $1.count { return $0.total > $1.total }
                return $0.count > $1.count
            }
            .first
    }

    private func aiCommandCategoryBreakdownDetail(items: [HomeItem], total: Double, fallback: String) -> String {
        guard total > 0 else { return fallback }
        let rows = Dictionary(grouping: items, by: \.category)
            .map { category, rows in
                (category: category, count: rows.count, total: rows.reduce(0) { $0 + $1.amount })
            }
            .sorted {
                if $0.total == $1.total { return $0.count > $1.count }
                return $0.total > $1.total
            }
            .prefix(3)
            .map { row in
                let percent = Int(((row.total / total) * 100).rounded())
                return "\(row.category.rawValue) \(row.count) 笔，占 \(percent)%"
            }
            .joined(separator: "；")
        return rows.isEmpty ? fallback : rows
    }

    private func buildDuplicateCheckResult(range: AICommandTimeRange) -> AICommandResult {
        let groups = duplicateGroups(in: range)
        let suspects = uniqueAICommandItems(groups.flatMap(\.items))
        let summary = suspects.isEmpty
            ? "\(range.label)没发现高置信导入重复。"
            : "\(range.label)发现 \(groups.count) 组、\(suspects.count) 笔可能重复的智能导入记录，先列出来给你核对。"
        let detail = suspects.isEmpty
            ? "主要检查同一张账单截图重复导入造成的同日、同金额、同分类记录；手动逐笔记录默认不草率判重。"
            : "已按疑似程度排序。判断依据：\(groups.prefix(3).map(\.reason).joined(separator: "；"))。不会自动合并或删除。"
        return AICommandResult(
            kind: .duplicateCheck,
            title: "重复记录初筛",
            summary: summary,
            detail: detail,
            items: sortedAICommandEvidenceItems(suspects),
            bars: suspects.isEmpty ? [] : dailyBars(range: range, items: suspects),
            drafts: [],
            amountSource: nil,
            needsAmount: false
        )
    }

    private func buildCommuteDraftResult(command: String) -> AICommandResult {
        let range = commuteDraftRange(from: command)
        let commandAmount = amountFromCommand(command)
        let typedAmount = Double(aiCommandAmountText.replacingOccurrences(of: ",", with: ""))
        let amount: Double?
        if let commandAmount {
            amount = commandAmount
        } else {
            amount = typedAmount
        }
        let inferred = inferredCommuteAmount()
        let resolvedAmount: Double?
        if let amount {
            resolvedAmount = amount
        } else {
            resolvedAmount = inferred?.amount
        }
        guard let resolvedAmount, resolvedAmount > 0 else {
            return AICommandResult(
                kind: .needsAmount,
                title: "可以补通勤，但还缺单程金额",
                summary: "我会按\(range.label)工作日，早晚各一次，先生成待确认记录。",
                detail: "没有找到足够明确的历史通勤金额，填一个单程金额后再生成。",
                items: [],
                bars: [],
                drafts: [],
                amountSource: nil,
                needsAmount: true
            )
        }

        let draftWeekdays = Array(commuteWorkdays(in: range).suffix(5))
        let commuteCandidates = filteredAICommandItems(range: range, category: .transport)
        let drafts = draftWeekdays.flatMap { day in
            commuteDrafts(for: day, amount: resolvedAmount, candidates: commuteCandidates)
        }
        guard !drafts.isEmpty else {
            return AICommandResult(
                kind: .unsupported,
                title: "\(range.label)没有可补的工作日",
                summary: "这条补记指令需要落在工作日上，换成本周、上周或最近一周会更稳。",
                detail: "不会自动新增任何记录。",
                items: [],
                bars: [],
                drafts: [],
                amountSource: nil,
                needsAmount: false
            )
        }
        let saveableDrafts = drafts.filter { draft in
            if case .conflict = draft.status { return false }
            return true
        }
        let total = saveableDrafts.reduce(0) { $0 + $1.amount }
        let amountSource: String
        if amount != nil {
            amountSource = "按输入金额"
        } else if let inferred {
            amountSource = "参考历史 \(inferred.count) 次"
        } else {
            amountSource = "按单程金额"
        }
        return AICommandResult(
            kind: .batchCreate,
            title: "补上\(range.label)通勤",
            summary: "可新增 \(saveableDrafts.count) 条出行记录，合计 \(total.formatted(.cny))。",
            detail: drafts.count == saveableDrafts.count
                ? "按周一到周五早晚生成，遇到节假日会跳过；保存前可先核对，不会自动写入账本。"
                : "已发现部分工作日早晚通勤可能已经存在，先用高亮标出并排除保存；节假日会跳过。",
            items: [],
            bars: dailyBarsForDrafts(drafts, weekdays: draftWeekdays),
            drafts: drafts,
            amountSource: amountSource,
            needsAmount: false
        )
    }

    private func saveAICommandDrafts(_ drafts: [AICommandRecordDraft]) {
        guard hasMemberAccess else {
            openMemberPricingAfterAICommandDismiss()
            return
        }
        let count = homeViewModel.importAICommandDrafts(drafts)
        aiCommandSavedCount = count
        aiCommandMessage = count > 0 ? "已确认保存，账本会按时间排序。" : "没有可保存的记录。"
        if count > 0 {
            aiCommandResult = nil
        }
    }

    private func openMemberPricingAfterAICommandDismiss() {
        showAICommandSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            onShowMemberPricing?()
        }
    }

    private func aiCommandMemoryItemMatches(_ item: HomeItem, command: String) -> Bool {
        let text = [
            item.title,
            item.emotionTag,
            item.displayEmotionTag,
            item.category.rawValue,
            item.category.label,
            item.memoryContext?.cityName ?? "",
            item.memoryContext?.semanticPlace ?? ""
        ]
            .joined(separator: " ")
            .lowercased()

        if containsAny(command, ["通勤", "上班", "下班", "地铁", "公交"]) {
            guard item.category == .transport,
                  containsAny(text, ["通勤", "上班", "下班", "地铁", "公交", "早高峰", "晚高峰"]) || item.amount <= 80 else {
                return false
            }
        } else if let intent = aiCommandCategoryIntent(from: command) {
            let categoryMatched = intent.categories.contains(item.category)
            let keywordMatched = aiCommandItemMatchesKeywords(item, keywords: intent.keywords)
            guard intent.requiresKeywordMatch ? categoryMatched && keywordMatched : categoryMatched || keywordMatched else {
                return false
            }
        } else if let lifeMarkIntent = LifeMarkService.queryIntent(from: command) {
            guard LifeMarkService.matches(item, intent: lifeMarkIntent) else {
                return false
            }
        }

        if containsAny(command, ["下雨", "雨天", "雨"]) {
            return item.memoryContext?.weatherKind == "rain"
                || containsAny(text, ["下雨", "雨天", "雨天通勤", "雨天出行"])
        }
        if containsAny(command, ["下雪", "雪天", "雪"]) {
            return item.memoryContext?.weatherKind == "snow"
                || containsAny(text, ["下雪", "雪天"])
        }
        if containsAny(command, ["外地", "旅游", "旅行", "出差"]) {
            return item.memoryContext?.semanticPlace == "外地"
                || containsAny(text, ["外地", "旅游", "旅行", "出差"])
        }
        if containsAny(command, ["城市"]) {
            return item.memoryContext?.cityName != nil
        }
        return item.memoryContext != nil
    }

    private func aiCommandRelatedMemoryItems(anchor: HomeItem, command: String) -> [HomeItem] {
        let calendar = Calendar.current
        let sameDayItems = homeViewModel.items.filter { item in
            item.amount > 0 && calendar.isDate(item.createdAt, inSameDayAs: anchor.createdAt)
        }
        let related = sameDayItems.filter { item in
            if item.id == anchor.id { return true }
            return aiCommandMemoryItemMatches(item, command: command)
                || aiCommandSameSceneMemoryItem(item, anchor: anchor, command: command)
        }
        return uniqueAICommandItems(related).sorted { $0.createdAt > $1.createdAt }
    }

    private func aiCommandSameSceneMemoryItem(_ item: HomeItem, anchor: HomeItem, command: String) -> Bool {
        let text = "\(item.title) \(item.emotionTag) \(item.displayEmotionTag) \(item.category.rawValue)"
        let anchorText = "\(anchor.title) \(anchor.emotionTag) \(anchor.displayEmotionTag) \(anchor.category.rawValue)"
        let asksRain = containsAny(command, ["下雨", "雨天", "雨"])
        let asksCommute = containsAny(command, ["通勤", "上班", "下班", "地铁", "公交"])

        if asksRain && asksCommute {
            guard item.category == .transport else { return false }
            let itemRain = item.memoryContext?.weatherKind == "rain" || containsAny(text, ["下雨", "雨天"])
            let itemCommute = containsAny(text, ["通勤", "上班", "下班", "地铁", "公交"]) || item.amount <= 40
            return itemRain && itemCommute
        }

        if asksRain {
            return item.memoryContext?.weatherKind == "rain" || containsAny(text, ["下雨", "雨天"])
        }

        if asksCommute {
            guard item.category == .transport else { return false }
            return containsAny(text, ["通勤", "上班", "下班", "地铁", "公交"]) || item.amount <= 40
        }

        if let semantic = anchor.memoryContext?.semanticPlace, semantic == item.memoryContext?.semanticPlace {
            return true
        }
        if let city = anchor.memoryContext?.cityName, city == item.memoryContext?.cityName {
            return true
        }
        return item.category == anchor.category
            && containsAny(text, anchorText.components(separatedBy: .whitespacesAndNewlines).filter { $0.count >= 2 })
    }

    private func aiCommandMemoryTitle(command: String, item: HomeItem) -> String {
        if containsAny(command, ["下雨", "雨天", "雨"]),
           containsAny(command, ["通勤", "上班", "下班", "地铁", "公交"]) {
            return "上一次雨天通勤"
        }
        if containsAny(command, ["下雨", "雨天", "雨"]) {
            return "上一次雨天记录"
        }
        if item.memoryContext?.semanticPlace == "外地", let city = item.memoryContext?.cityName {
            return "\(city)的那次记录"
        }
        return "找到一段生活记忆"
    }

    private func aiCommandMemoryContextLine(_ context: HomeItem.MemoryContext?) -> String {
        guard let context else { return "" }
        var parts: [String] = []
        if let weatherKind = context.weatherKind {
            switch weatherKind {
            case "rain":
                parts.append("雨天")
            case "snow":
                parts.append("雪天")
            case "hot":
                parts.append("偏热")
            case "cold":
                parts.append("偏冷")
            default:
                parts.append("天气普通")
            }
        }
        if let temperature = context.temperatureCelsius {
            parts.append("\(Int(temperature.rounded()))℃")
        }
        if let city = context.cityName {
            if let semantic = context.semanticPlace {
                parts.append("\(city) · \(semantic)")
            } else {
                parts.append(city)
            }
        } else if let semantic = context.semanticPlace {
            parts.append(semantic)
        }
        return parts.joined(separator: " · ")
    }

    private func shouldShowHomeEmotionLike(_ item: HomeItem) -> Bool {
        let tag = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return false }
        return tag != HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
    }

    private func filteredAICommandItems(range: AICommandTimeRange, category: HomeItem.Category?) -> [HomeItem] {
        let intent = category.map { AICommandCategoryIntent(categories: [$0], label: $0.label, keywords: []) }
        return filteredAICommandItems(range: range, intent: intent)
    }

    private func filteredAICommandItems(range: AICommandTimeRange, intent: AICommandCategoryIntent?) -> [HomeItem] {
        let cacheKey = aiCommandItemsCacheKey(range: range, intent: intent)
        if let cached = Self.aiCommandItemsCache[cacheKey] {
            return cached
        }

        let result = sortedAICommandEvidenceItems(homeViewModel.items.filter { item in
            guard item.amount > 0, range.contains(item.createdAt) else { return false }
            guard let intent else { return true }
            let categoryMatched = intent.categories.contains(item.category)
            let keywordMatched = aiCommandItemMatchesKeywords(item, keywords: intent.keywords)
            return intent.requiresKeywordMatch
                ? categoryMatched && keywordMatched
                : categoryMatched || keywordMatched
        })
        storeAICommandItems(result, for: cacheKey)
        return result
    }

    private func filteredAICommandLifeMarkItems(
        range: AICommandTimeRange,
        intent: LifeMarkQueryIntent,
        command: String = ""
    ) -> [HomeItem] {
        let cacheKey = aiCommandLifeMarkItemsCacheKey(range: range, intent: intent, command: command)
        if let cached = Self.aiCommandLifeMarkItemsCache[cacheKey] {
            return cached
        }

        let items = homeViewModel.items.filter { item in
            item.amount > 0
                && range.contains(item.createdAt)
                && LifeMarkService.matches(item, intent: intent)
        }
        let result = sortedAICommandEvidenceItems(aiCommandScopedLifeMarkItems(items, intent: intent, command: command))
        storeAICommandLifeMarkItems(result, for: cacheKey)
        return result
    }

    private func aiCommandItemsCacheKey(
        range: AICommandTimeRange,
        intent: AICommandCategoryIntent?
    ) -> String {
        let intentKey: String
        if let intent {
            intentKey = [
                intent.label,
                intent.categories.map(\.rawValue).joined(separator: ","),
                intent.keywords.joined(separator: ","),
                intent.requiresKeywordMatch ? "strict" : "loose"
            ].joined(separator: "#")
        } else {
            intentKey = "all"
        }
        return [
            "items",
            range.label,
            aiCommandDateCacheKey(range.start),
            aiCommandDateCacheKey(range.end),
            intentKey,
            aiCommandItemsSignature(homeViewModel.items)
        ].joined(separator: "|")
    }

    private func aiCommandLifeMarkItemsCacheKey(
        range: AICommandTimeRange,
        intent: LifeMarkQueryIntent,
        command: String
    ) -> String {
        [
            "lifeMark",
            range.label,
            aiCommandDateCacheKey(range.start),
            aiCommandDateCacheKey(range.end),
            intent.id,
            intent.label,
            intent.categories.map(\.rawValue).joined(separator: ","),
            intent.keywords.joined(separator: ","),
            intent.requiresKeywordMatch ? "strict" : "loose",
            command,
            aiCommandItemsSignature(homeViewModel.items)
        ].joined(separator: "|")
    }

    private func aiCommandDateCacheKey(_ date: Date) -> String {
        if date == .distantPast {
            return "distantPast"
        }
        if date == .distantFuture {
            return "distantFuture"
        }
        return "\(Int(date.timeIntervalSince1970))"
    }

    private func storeAICommandItems(_ items: [HomeItem], for key: String) {
        guard Self.aiCommandItemsCache[key] == nil else {
            return
        }
        Self.aiCommandItemsCache[key] = items
        rememberAICommandCacheKey("items|\(key)")
    }

    private func storeAICommandLifeMarkItems(_ items: [HomeItem], for key: String) {
        guard Self.aiCommandLifeMarkItemsCache[key] == nil else {
            return
        }
        Self.aiCommandLifeMarkItemsCache[key] = items
        rememberAICommandCacheKey("lifeMark|\(key)")
    }

    private func aiCommandItemsSignature(_ items: [HomeItem]) -> String {
        var hasher = Hasher()
        hasher.combine(items.count)
        for item in items {
            hasher.combine(item.id)
            hasher.combine(item.createdAt.timeIntervalSince1970)
            hasher.combine(item.updatedAt.timeIntervalSince1970)
            hasher.combine(item.amount)
            hasher.combine(item.category.rawValue)
            hasher.combine(item.title)
            hasher.combine(item.emotionTag)
            hasher.combine(item.source.rawValue)
            hasher.combine(item.draftMeta?.status.rawValue)
            hasher.combine(item.memoryContext?.weatherKind)
            hasher.combine(item.memoryContext?.cityName)
            hasher.combine(item.memoryContext?.semanticPlace)
            hasher.combine(item.scenePackId)
        }
        return "\(hasher.finalize())"
    }

    private func rememberAICommandCacheKey(_ typedKey: String) {
        Self.aiCommandCacheOrder.append(typedKey)
        while Self.aiCommandCacheOrder.count > Self.aiCommandCacheLimit {
            let staleTypedKey = Self.aiCommandCacheOrder.removeFirst()
            removeAICommandCacheValue(for: staleTypedKey)
        }
    }

    private func removeAICommandCacheValue(for typedKey: String) {
        let parts = typedKey.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        switch parts[0] {
        case "suggestions":
            Self.aiCommandSuggestionsCache.removeValue(forKey: parts[1])
        case "items":
            Self.aiCommandItemsCache.removeValue(forKey: parts[1])
        case "lifeMark":
            Self.aiCommandLifeMarkItemsCache.removeValue(forKey: parts[1])
        default:
            break
        }
    }

    private func aiCommandScopedLifeMarkItems(
        _ items: [HomeItem],
        intent: LifeMarkQueryIntent,
        command: String
    ) -> [HomeItem] {
        guard intent.id == "home_utilities",
              let rentKeywords = aiCommandRentKeywords(from: command) else {
            return items
        }
        return items.filter { aiCommandItemMatchesRentKeywords($0, keywords: rentKeywords) }
    }

    private func aiCommandLifeMarkLabel(_ intent: LifeMarkQueryIntent?, command: String) -> String? {
        guard let intent else { return nil }
        if intent.id == "home_utilities", aiCommandRentKeywords(from: command) != nil {
            return "房租"
        }
        return intent.label
    }

    private func aiCommandRentKeywords(from command: String) -> [String]? {
        let keywords = ["房租", "租金", "租房", "租房子", "租屋", "租赁", "押金", "房东"]
        return containsAny(command, keywords) ? keywords : nil
    }

    private func aiCommandItemMatchesRentKeywords(_ item: HomeItem, keywords: [String]) -> Bool {
        let titleText = [
            item.title,
            item.displayTitle
        ]
            .joined(separator: " ")
            .lowercased()
        if containsAny(titleText, keywords) {
            return true
        }

        let tagText = [
            item.emotionTag,
            item.displayEmotionTag
        ]
            .filter { !$0.localizedCaseInsensitiveContains("房租水电物业") }
            .joined(separator: " ")
            .lowercased()
        return containsAny(tagText, keywords)
    }

    private func aiCommandItemMatchesKeywords(_ item: HomeItem, keywords: [String]) -> Bool {
        guard !keywords.isEmpty else { return false }
        let text = [
            item.title,
            item.emotionTag,
            item.displayEmotionTag,
            item.category.rawValue,
            item.category.label
        ]
            .joined(separator: " ")
            .lowercased()
        return containsAny(text, keywords)
    }

    private func aiCommandHasExplicitTimeRange(_ text: String) -> Bool {
        if containsAny(text, ["今天", "今日", "今儿", "昨天", "昨日", "昨儿", "这阵子", "近来", "这段时间"]) {
            return true
        }
        if containsAny(text, ["本周", "这周", "这一周", "本自然周", "这个自然周", "本星期", "这个星期", "这星期", "这一星期", "本礼拜", "这个礼拜", "这礼拜", "这一礼拜", "上周", "上一周", "上个自然周", "上一个自然周", "上星期", "上个星期", "上一个星期", "上礼拜", "上个礼拜", "上一个礼拜"]) {
            return true
        }
        if containsAny(text, ["本月", "这个月", "这月", "本月份", "这个月份", "这月份", "当月", "上个月", "上月", "上一个月", "上一月", "上月份", "上个自然月"]) {
            return true
        }
        return aiCommandExplicitRecentDays(from: text) != nil
            || aiCommandExplicitRecentWeeks(from: text) != nil
            || aiCommandExplicitRecentMonths(from: text) != nil
    }

    private func dailyBars(range: AICommandTimeRange, items: [HomeItem]) -> [AICommandBar] {
        let calendar = Calendar.current
        let days = max(1, min(range.barDays, 7))
        let finalDay = calendar.date(byAdding: .day, value: -1, to: range.end) ?? Date()
        let itemsByDay = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.createdAt)
        }
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - (days - 1), to: finalDay) else { return nil }
            let dayItems = itemsByDay[calendar.startOfDay(for: day)] ?? []
            return AICommandBar(
                label: shortDateText(day),
                amount: dayItems.reduce(0) { $0 + $1.amount },
                count: dayItems.count
            )
        }
    }

    private func dailyBarsForDrafts(_ drafts: [AICommandRecordDraft], weekdays: [Date]) -> [AICommandBar] {
        let calendar = Calendar.current
        let draftsByDay = Dictionary(grouping: drafts) { draft in
            calendar.startOfDay(for: draft.date)
        }
        return weekdays.map { day in
            let dayDrafts = (draftsByDay[calendar.startOfDay(for: day)] ?? []).filter {
                if case .conflict = $0.status { return false }
                return true
            }
            return AICommandBar(
                label: shortDateText(day),
                amount: dayDrafts.reduce(0) { $0 + $1.amount },
                count: dayDrafts.count
            )
        }
    }

    private func commuteDrafts(for day: Date, amount: Double, candidates: [HomeItem]) -> [AICommandRecordDraft] {
        [
            commuteDraft(
                title: "早高峰通勤",
                date: dateBySetting(hour: 8, minute: 30, on: day),
                amount: amount,
                window: 6...10,
                candidates: candidates
            ),
            commuteDraft(
                title: "晚高峰通勤",
                date: dateBySetting(hour: 18, minute: 30, on: day),
                amount: amount,
                window: 16...21,
                candidates: candidates
            )
        ]
    }

    private func commuteDraft(
        title: String,
        date: Date,
        amount: Double,
        window: ClosedRange<Int>,
        candidates: [HomeItem]
    ) -> AICommandRecordDraft {
        if let existing = existingCommuteLikeItem(on: date, amount: amount, window: window, candidates: candidates) {
            return AICommandRecordDraft(
                title: title,
                amount: amount,
                category: .transport,
                date: date,
                status: .conflict("\(existing.createdAt.zhBillTime) 已有「\(existing.displayTitle)」\(existing.amount.formatted(.cny))，像同一段通勤，先不重复补。")
            )
        }
        return AICommandRecordDraft(
            title: title,
            amount: amount,
            category: .transport,
            date: date
        )
    }

    private func existingCommuteLikeItem(
        on date: Date,
        amount: Double,
        window: ClosedRange<Int>,
        candidates: [HomeItem]
    ) -> HomeItem? {
        let calendar = Calendar.current
        guard isWeekday(date) else { return nil }
        return candidates
            .filter { item in
                guard item.amount > 0,
                      item.category == .transport,
                      calendar.isDate(item.createdAt, inSameDayAs: date),
                      window.contains(calendar.component(.hour, from: item.createdAt)),
                      commuteAmountMatchesHabit(existing: item.amount, proposed: amount) else {
                    return false
                }
                let text = "\(item.title) \(item.displayEmotionTag)"
                return containsAny(text, ["通勤", "地铁", "公交", "早高峰", "晚高峰", "上班", "下班"])
                    || item.amount <= max(20, amount * 1.5)
            }
            .sorted { lhs, rhs in
                abs(lhs.amount - amount) < abs(rhs.amount - amount)
            }
            .first
    }

    private func commuteAmountMatchesHabit(existing: Double, proposed: Double) -> Bool {
        let centsDelta = abs(existing - proposed)
        if centsDelta < 0.01 { return true }
        let tolerance = max(1.0, min(6.0, proposed * 0.22))
        return centsDelta <= tolerance
    }

    private func inferredCommuteAmount() -> (amount: Double, count: Int)? {
        let candidates = filteredAICommandItems(range: aiCommandRecentRange(days: 90, label: "最近 90 天"), category: .transport)
            .filter { item in
                let text = "\(item.title) \(item.displayEmotionTag)"
                let hour = Calendar.current.component(.hour, from: item.createdAt)
                let isRushHour = (6...10).contains(hour) || (16...21).contains(hour)
                return item.amount > 0
                    && item.amount <= 80
                    && isWeekday(item.createdAt)
                    && isRushHour
                    && (containsAny(text, ["通勤", "地铁", "公交", "早高峰", "晚高峰", "上班", "下班"]) || item.amount <= 15)
            }
        guard !candidates.isEmpty else { return nil }
        let grouped = Dictionary(grouping: candidates) { Int(($0.amount * 100).rounded()) }
        guard let best = grouped.max(by: { lhs, rhs in
            if lhs.value.count == rhs.value.count {
                let leftDate = lhs.value.map(\.createdAt).max() ?? .distantPast
                let rightDate = rhs.value.map(\.createdAt).max() ?? .distantPast
                return leftDate < rightDate
            }
            return lhs.value.count < rhs.value.count
        }) else { return nil }
        return (Double(best.key) / 100, best.value.count)
    }

    private func dateBySetting(hour: Int, minute: Int, on day: Date) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private func aiCommandTimeRange(from text: String, defaultRecentDays: Int = 3) -> AICommandTimeRange {
        let calendar = aiCommandCalendar
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        if let explicitDays = aiCommandExplicitRecentDays(from: text) {
            return aiCommandRecentRange(days: explicitDays, label: "最近 \(explicitDays) 天")
        }
        if let explicitWeeks = aiCommandExplicitRecentWeeks(from: text) {
            return aiCommandRecentRange(days: explicitWeeks * 7, label: explicitWeeks == 1 ? "最近一周" : "最近 \(explicitWeeks) 周")
        }
        if let explicitMonths = aiCommandExplicitRecentMonths(from: text) {
            return aiCommandRecentMonthRange(months: explicitMonths, label: explicitMonths == 1 ? "最近一个月" : "最近 \(explicitMonths) 个月")
        }

        if containsAny(text, ["今天", "今日", "今儿", "今天这天"]) {
            let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
            return AICommandTimeRange(label: "今天", start: todayStart, end: end, barDays: 1)
        }
        if containsAny(text, ["昨天", "昨日", "昨儿"]) {
            let start = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            return AICommandTimeRange(label: "昨天", start: start, end: todayStart, barDays: 1)
        }
        if containsAny(text, ["过去三天", "近三天", "最近三天", "3天", "3 天", "三天"]) {
            return aiCommandRecentRange(days: 3, label: "过去 3 天")
        }
        if containsAny(text, ["本周", "这周", "这一周", "本自然周", "这个自然周", "本星期", "这个星期", "这星期", "这一星期", "本礼拜", "这个礼拜", "这礼拜", "这一礼拜"]) {
            let start = aiCommandNaturalWeekStart(for: now)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
            let naturalEnd = calendar.date(byAdding: .day, value: 7, to: start) ?? tomorrow
            let end = min(tomorrow, naturalEnd)
            return AICommandTimeRange(label: "本周", start: start, end: end, barDays: daysBetween(start, end))
        }
        if containsAny(text, ["上周", "上一周", "上个自然周", "上一个自然周", "上星期", "上个星期", "上一个星期", "上礼拜", "上个礼拜", "上一个礼拜"]) {
            let end = aiCommandNaturalWeekStart(for: now)
            let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
            return AICommandTimeRange(label: "上周", start: start, end: end, barDays: 7)
        }
        if containsAny(text, ["最近7天", "最近 7 天", "最近七天", "过去7天", "过去 7 天", "近7天", "近 7 天", "七天", "一周", "一星期", "一个星期", "一礼拜", "一个礼拜", "过去一周", "过去一星期", "过去一礼拜", "最近一周", "最近一星期", "最近一礼拜"]) {
            return aiCommandRecentRange(days: 7, label: "最近 7 天")
        }
        if containsAny(text, ["本月", "这个月", "这月", "本月份", "这个月份", "这月份", "当月"]) {
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? todayStart
            let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
            return AICommandTimeRange(label: "本月", start: start, end: end, barDays: daysBetween(start, end))
        }
        if containsAny(text, ["上个月", "上月", "上一个月", "上一月", "上月份", "上个自然月"]) {
            let end = calendar.dateInterval(of: .month, for: now)?.start ?? todayStart
            let start = calendar.date(byAdding: .month, value: -1, to: end) ?? end
            return AICommandTimeRange(label: "上个月", start: start, end: end, barDays: daysBetween(start, end))
        }
        if containsAny(text, ["这阵子", "最近", "近来", "这段时间"]) {
            var range = aiCommandRecentRange(days: 7, label: "最近 7 天")
            range.isFallback = true
            return range
        }
        return aiCommandRecentRange(days: defaultRecentDays, label: defaultRecentDays == 7 ? "最近 7 天" : "过去 \(defaultRecentDays) 天")
    }

    private func aiCommandRecentRange(days: Int, label: String) -> AICommandTimeRange {
        let calendar = aiCommandCalendar
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let safeDays = max(1, days)
        let start = calendar.date(byAdding: .day, value: -(safeDays - 1), to: todayStart) ?? todayStart
        let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        return AICommandTimeRange(label: label, start: start, end: end, barDays: safeDays)
    }

    private func aiCommandRecentMonthRange(months: Int, label: String) -> AICommandTimeRange {
        let calendar = aiCommandCalendar
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let safeMonths = max(1, min(months, 12))
        let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        let start = calendar.date(byAdding: .month, value: -safeMonths, to: end) ?? todayStart
        return AICommandTimeRange(label: label, start: start, end: end, barDays: daysBetween(start, end))
    }

    private var aiCommandAllTimeRange: AICommandTimeRange {
        AICommandTimeRange(
            label: "全部",
            start: .distantPast,
            end: .distantFuture,
            barDays: 7
        )
    }

    private func aiCommandExplicitRecentDays(from text: String) -> Int? {
        let hasRecentContext = containsAny(text, ["最近", "过去", "近", "前"])
        if hasRecentContext, containsAny(text, ["半个月", "半月"]) {
            return 15
        }
        guard containsAny(text, ["最近", "过去", "近", "前"]),
              containsAny(text, ["天", "日"]) else { return nil }
        if containsAny(text, ["几天", "几日"]) {
            return 7
        }
        if let number = aiCommandArabicDayCount(from: text) {
            return min(max(number, 1), 31)
        }
        if let number = aiCommandChineseDayCount(from: text) {
            return min(max(number, 1), 31)
        }
        return nil
    }

    private func aiCommandArabicDayCount(from text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{1,2})\s*(天|日)"#) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let numberRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[numberRange])
    }

    private func aiCommandChineseDayCount(from text: String) -> Int? {
        let candidates: [(String, Int)] = [
            ("三十", 30), ("二十九", 29), ("二十八", 28), ("二十七", 27), ("二十六", 26),
            ("二十五", 25), ("二十四", 24), ("二十三", 23), ("二十二", 22), ("二十一", 21),
            ("二十", 20), ("十九", 19), ("十八", 18), ("十七", 17), ("十六", 16),
            ("十五", 15), ("十四", 14), ("十三", 13), ("十二", 12), ("十一", 11),
            ("十", 10), ("九", 9), ("八", 8), ("七", 7), ("六", 6),
            ("五", 5), ("四", 4), ("三", 3), ("二", 2), ("两", 2), ("一", 1)
        ]
        return candidates.first { text.contains("\($0.0)天") || text.contains("\($0.0)日") }?.1
    }

    private func aiCommandExplicitRecentWeeks(from text: String) -> Int? {
        if containsAny(text, ["本周", "这周", "这一周", "本自然周", "这个自然周", "本星期", "这个星期", "这星期", "这一星期", "本礼拜", "这个礼拜", "这礼拜", "这一礼拜", "上周", "上一周", "上个自然周", "上一个自然周", "上星期", "上个星期", "上一个星期", "上礼拜", "上个礼拜", "上一个礼拜"]) {
            return nil
        }
        let hasRecentContext = containsAny(text, ["最近", "过去", "近", "前"])
        let hasExplicitWeekSpan = containsAny(text, ["一周", "两周", "二周", "个星期", "个礼拜", "一星期", "两星期", "二星期", "一礼拜", "两礼拜", "二礼拜"])
        guard (hasRecentContext || hasExplicitWeekSpan),
              containsAny(text, ["周", "星期", "礼拜"]) else { return nil }
        if containsAny(text, ["几周", "几个星期", "几个礼拜"]) {
            return 1
        }
        if let number = aiCommandArabicWeekCount(from: text) {
            return min(max(number, 1), 12)
        }
        if let number = aiCommandChineseWeekCount(from: text) {
            return min(max(number, 1), 12)
        }
        return containsAny(text, ["一周", "一个星期", "一星期", "一个礼拜", "一礼拜"]) ? 1 : nil
    }

    private func aiCommandArabicWeekCount(from text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{1,2})\s*(周|个?\s*星期|个?\s*礼拜)"#) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let numberRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[numberRange])
    }

    private func aiCommandChineseWeekCount(from text: String) -> Int? {
        let candidates: [(String, Int)] = [
            ("十二", 12), ("十一", 11), ("十", 10), ("九", 9), ("八", 8),
            ("七", 7), ("六", 6), ("五", 5), ("四", 4), ("三", 3),
            ("两", 2), ("二", 2), ("一", 1)
        ]
        return candidates.first { candidate in
            let value = candidate.0
            return text.contains("\(value)周")
                || text.contains("\(value)星期")
                || text.contains("\(value)个星期")
                || text.contains("\(value)礼拜")
                || text.contains("\(value)个礼拜")
        }?.1
    }

    private func aiCommandExplicitRecentMonths(from text: String) -> Int? {
        if containsAny(text, ["本月", "这个月", "这月", "本月份", "这个月份", "这月份", "当月", "上个月", "上月", "上一个月", "上一月", "上月份", "上个自然月"]) {
            return nil
        }
        let hasRecentContext = containsAny(text, ["最近", "过去", "近", "前"])
        let hasExplicitMonthSpan = containsAny(text, ["个月"])
        guard (hasRecentContext || hasExplicitMonthSpan),
              containsAny(text, ["个月", "月"]) else { return nil }
        if containsAny(text, ["几个月"]) {
            return 1
        }
        if let number = aiCommandArabicMonthCount(from: text) {
            return min(max(number, 1), 12)
        }
        if let number = aiCommandChineseMonthCount(from: text) {
            return min(max(number, 1), 12)
        }
        return containsAny(text, ["一个月", "一月"]) ? 1 : nil
    }

    private func aiCommandArabicMonthCount(from text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{1,2})\s*个?\s*月"#) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let numberRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[numberRange])
    }

    private func aiCommandChineseMonthCount(from text: String) -> Int? {
        let candidates: [(String, Int)] = [
            ("十二", 12), ("十一", 11), ("十", 10), ("九", 9), ("八", 8),
            ("七", 7), ("六", 6), ("五", 5), ("四", 4), ("三", 3),
            ("两", 2), ("二", 2), ("一", 1)
        ]
        return candidates.first { text.contains("\($0.0)个月") || text.contains("\($0.0)月") }?.1
    }

    private func commuteDraftRange(from text: String) -> AICommandTimeRange {
        let explicitRange = aiCommandTimeRange(from: text, defaultRecentDays: 7)
        if containsAny(text, ["上周", "上一周", "上个自然周", "上一个自然周", "上星期", "上个星期", "上一个星期", "上礼拜", "上个礼拜", "上一个礼拜", "本周", "这周", "这一周", "本自然周", "这个自然周", "本星期", "这个星期", "这星期", "这一星期", "本礼拜", "这个礼拜", "这礼拜", "这一礼拜", "最近", "过去", "近", "前", "7天", "七天", "一周", "一星期", "一个星期", "一礼拜", "一个礼拜", "半个月", "半月", "个月"]) {
            return explicitRange
        }
        return aiCommandRecentRange(days: 7, label: "最近一周")
    }

    private func commuteWorkdays(in range: AICommandTimeRange) -> [Date] {
        let calendar = aiCommandCalendar
        var days: [Date] = []
        var cursor = calendar.startOfDay(for: range.start)
        while cursor < range.end {
            if isCommuteWorkday(cursor) {
                days.append(cursor)
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? range.end
        }
        return days
    }

    private var aiCommandCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Calendar.current.timeZone
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }

    private func aiCommandNaturalWeekStart(for date: Date) -> Date {
        aiCommandCalendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? aiCommandCalendar.startOfDay(for: date)
    }

    private func isCommuteWorkday(_ date: Date) -> Bool {
        guard isWeekday(date) else { return false }
        return !isKnownMainlandChinaHoliday(date)
    }

    private func isWeekday(_ date: Date) -> Bool {
        let weekday = aiCommandCalendar.component(.weekday, from: date)
        return weekday >= 2 && weekday <= 6
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        max(1, aiCommandCalendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    private func isKnownMainlandChinaHoliday(_ date: Date) -> Bool {
        if Self.mainlandChinaHolidayOverrides.contains(gregorianDateKey(for: date)) {
            return true
        }
        let components = aiCommandCalendar.dateComponents([.month, .day], from: date)
        if components.month == 1 && components.day == 1 {
            return true
        }
        if components.month == 5 && components.day == 1 {
            return true
        }
        if components.month == 10 && (1...3).contains(components.day ?? 0) {
            return true
        }
        return isTraditionalMainlandChinaPublicFestival(date)
    }

    private func isTraditionalMainlandChinaPublicFestival(_ date: Date) -> Bool {
        var lunarCalendar = Calendar(identifier: .chinese)
        lunarCalendar.timeZone = aiCommandCalendar.timeZone
        let components = lunarCalendar.dateComponents([.month, .day, .isLeapMonth], from: date)
        guard components.isLeapMonth != true else { return false }
        if components.month == 1 && (1...3).contains(components.day ?? 0) {
            return true
        }
        if components.month == 5 && components.day == 5 {
            return true
        }
        if components.month == 8 && components.day == 15 {
            return true
        }
        return false
    }

    private func gregorianDateKey(for date: Date) -> String {
        let components = aiCommandCalendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func aiCommandCategoryIntent(from text: String) -> AICommandCategoryIntent? {
        let lexicon: [AICommandCategoryIntent] = [
            AICommandCategoryIntent(
                categories: [.health, .shopping, .entertainment, .daily],
                label: "运动",
                keywords: ["运动", "健身", "训练", "跑步", "瑜伽", "游泳", "球场", "私教", "课程", "护具", "运动鞋", "运动服", "健身卡", "月卡", "年卡", "补给", "能量", "恢复", "按摩", "锻炼"],
                requiresKeywordMatch: true
            ),
            AICommandCategoryIntent(
                categories: [.dining],
                label: "餐饮",
                keywords: ["餐饮", "吃饭", "吃的", "饭", "美食", "外卖", "美团外卖", "饿了么", "抖音团购", "七欣天", "海底捞", "肯德基", "麦当劳", "必胜客", "塔斯汀", "华莱士", "食堂", "早餐", "早饭", "午餐", "午饭", "晚餐", "晚饭", "夜宵", "简餐", "咖啡", "奶茶", "饮品", "饭店", "餐厅", "火锅", "烤肉", "麻辣烫", "披萨", "炸鸡", "汉堡", "卤味", "面", "粉", "包子", "盒饭"]
            ),
            AICommandCategoryIntent(
                categories: [.daily, .shopping, .health],
                label: "娃和毛孩",
                keywords: ["娃", "宝宝", "孩子", "婴儿", "奶粉", "尿不湿", "纸尿裤", "拉拉裤", "辅食", "奶瓶", "安抚奶嘴", "宝宝湿巾", "婴儿湿巾", "童装", "儿童座椅", "推车", "宠物", "毛孩子", "毛孩", "狗粮", "猫粮", "猫砂", "宠物粮", "宠物口粮", "尿垫", "冻干", "宠物罐头", "驱虫", "宠物医院", "洗护"],
                requiresKeywordMatch: true
            ),
            AICommandCategoryIntent(
                categories: [.transport, .lodging, .entertainment, .dining, .shopping],
                label: "旅行出行",
                keywords: ["旅行", "旅游", "出去玩", "异地", "外地", "出差", "酒店", "民宿", "住宿", "机票", "机场", "高铁", "火车", "车站", "景区", "景点", "门票", "返程", "行程", "伴手礼", "露营地"],
                requiresKeywordMatch: true
            ),
            AICommandCategoryIntent(
                categories: [.shopping, .daily, .health, .entertainment],
                label: "兴趣装备",
                keywords: ["兴趣装备", "装备", "渔具", "鱼竿", "鱼线", "鱼饵", "路亚", "钓箱", "钓椅", "露营", "帐篷", "天幕", "睡袋", "骑行", "头盔", "码表", "摄影", "相机", "镜头", "模型", "手办", "乐器", "吉他", "键盘", "茶具", "咖啡器具", "磨豆机", "滤杯"],
                requiresKeywordMatch: true
            ),
            AICommandCategoryIntent(
                categories: [.transport],
                label: "交通",
                keywords: ["交通", "出行", "通勤", "地铁", "公交", "打车", "出租", "网约车", "滴滴", "停车", "加油", "路费", "高铁", "火车", "机票", "机场"]
            ),
            AICommandCategoryIntent(
                categories: [.daily, .home],
                label: "日用",
                keywords: ["日用", "超市", "便利店", "纸巾", "清洁", "生活用品", "洗衣", "洗护", "日用品", "买菜", "水果", "蔬菜", "生鲜", "盒马", "叮咚", "叮咚买菜", "小象", "小象超市", "京东到家", "京东秒送", "美团闪购", "朴朴", "淘宝买菜", "即时零售", "居家"]
            ),
            AICommandCategoryIntent(
                categories: [.health],
                label: "健康",
                keywords: ["健康", "药", "买药", "医院", "挂号", "门诊", "体检", "护理", "牙", "眼镜"]
            ),
            AICommandCategoryIntent(
                categories: [.shopping],
                label: "购物",
                keywords: ["购物", "衣服", "鞋", "包", "淘宝", "京东", "拼多多", "买到", "添置", "快递", "数码", "渔具", "鱼竿", "鱼线", "鱼饵", "路亚", "钓箱", "钓椅", "露营", "帐篷", "天幕", "睡袋", "骑行", "头盔", "码表", "摄影", "相机", "镜头", "模型", "手办", "乐器", "茶具", "咖啡器具"]
            ),
            AICommandCategoryIntent(
                categories: [.entertainment],
                label: "娱乐",
                keywords: [
                    "娱乐", "休闲", "电影", "影院", "游戏", "演出", "门票", "放松", "唱歌", "ktv",
                    "动物园", "游乐场", "乐园", "主题乐园", "迪士尼", "环球影城", "海洋馆", "水族馆",
                    "公园", "景区", "景点", "展览", "看展", "展馆", "博物馆", "美术馆",
                    "演唱会", "音乐节", "剧场", "话剧", "脱口秀", "密室", "剧本杀", "桌游", "台球"
                ]
            )
        ]
        return lexicon.first { containsAny(text, $0.keywords) }
    }

    private func sortedAICommandEvidenceItems(_ items: [HomeItem]) -> [HomeItem] {
        items.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.amount > rhs.amount
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func uniqueAICommandItems(_ items: [HomeItem]) -> [HomeItem] {
        var seen = Set<UUID>()
        return items.filter { item in
            if seen.contains(item.id) { return false }
            seen.insert(item.id)
            return true
        }
    }

    private func duplicateGroups(in range: AICommandTimeRange) -> [AICommandDuplicateGroup] {
        let calendar = Calendar.current
        let items = filteredAICommandItems(range: range, category: nil)
            .filter { $0.source == .ocr || $0.draftMeta != nil }
        let exactGroups = Dictionary(grouping: items) { item in
            let cents = Int((item.amount * 100).rounded())
            let day = calendar.startOfDay(for: item.createdAt).timeIntervalSince1970
            let minuteBucket = calendar.component(.hour, from: item.createdAt) * 60 + calendar.component(.minute, from: item.createdAt)
            let normalizedMinuteBucket = minuteBucket / 5
            return "\(item.category.rawValue)-\(cents)-\(Int(day))-\(normalizedMinuteBucket)-\(normalizedDuplicateTitle(item.displayTitle))"
        }
        return exactGroups.values
            .filter { $0.count > 1 }
            .filter { group in
                let sources = Set(group.map(\.source))
                let allImported = sources.allSatisfy { $0 == .ocr }
                guard allImported || group.contains(where: { $0.draftMeta != nil }) else { return false }
                return group.allSatisfy { item in
                    group.contains { other in
                        item.id != other.id && strictDuplicateMatch(item, other, calendar: calendar)
                    }
                }
            }
            .map { group in
                let sorted = group.sorted { $0.createdAt < $1.createdAt }
                let score = 92 + min(8, (sorted.count - 2) * 4)
                let first = sorted[0]
                let reason = "\(first.createdAt.zhBillDateTime) 附近 \(first.category.rawValue) \(first.amount.formatted(.cny)) 出现 \(sorted.count) 条智能导入记录"
                return AICommandDuplicateGroup(
                    id: sorted.map { $0.id.uuidString }.joined(separator: "-"),
                    items: sorted,
                    score: score,
                    reason: reason
                )
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    let leftDate = lhs.items.map(\.createdAt).max() ?? .distantPast
                    let rightDate = rhs.items.map(\.createdAt).max() ?? .distantPast
                    return leftDate > rightDate
                }
                return lhs.score > rhs.score
            }
    }

    private func strictDuplicateMatch(_ lhs: HomeItem, _ rhs: HomeItem, calendar: Calendar) -> Bool {
        guard lhs.category == rhs.category,
              abs(lhs.amount - rhs.amount) < 0.01,
              calendar.isDate(lhs.createdAt, inSameDayAs: rhs.createdAt),
              abs(lhs.createdAt.timeIntervalSince(rhs.createdAt)) <= 5 * 60 else {
            return false
        }
        let leftTitle = normalizedDuplicateTitle(lhs.displayTitle)
        let rightTitle = normalizedDuplicateTitle(rhs.displayTitle)
        return leftTitle == rightTitle || leftTitle.contains(rightTitle) || rightTitle.contains(leftTitle)
    }

    private func normalizedDuplicateTitle(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
    }

    private func amountFromCommand(_ text: String) -> Double? {
        let pattern = #"(?:单程|每次|每趟|一次)?\s*(\d+(?:\.\d{1,2})?)\s*(?:元|块)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let amountRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let value = Double(text[amountRange])
        if let value, value > 0, value < 1000 {
            return value
        }
        return nil
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func aiCommandKindText(_ kind: AICommandKind) -> String {
        switch kind {
        case .query:
            return "查账"
        case .memoryLookup:
            return "回望"
        case .duplicateCheck:
            return "核对"
        case .batchCreate:
            return "待保存"
        case .needsAmount:
            return "需确认"
        case .unsupported:
            return "未识别"
        }
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
        let calendar = Calendar.current
        let now = Date()
        return homeViewModel.items.filter {
            calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month) && $0.amount > 0
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
        let shareTheme: WeeklyShareCardView.ShareCardTheme = settingsViewModel.shareCardUsesAppTheme && settingsViewModel.settings.hasMemberAccess
            ? .appTheme(ThemeResolver.current)
            : .journal
        let card = WeeklyShareCardView(
            payload: payload,
            isPetMode: petMode,
            nickname: nick,
            theme: shareTheme
        )
        guard let img = card.snapshot() else { return }
        isSavingWeeklyShareCard = true
        weeklyShareSaveMessage = nil
        showWeeklyShareThemeNudge = false
        Task {
            do {
                try await PhotoLibrarySaveService.shared.saveImageToLibrary(img)
                weeklyShareSaveMessage = "已保存到相册。"
                showWeeklyShareThemeNudge = shouldShowWeeklyShareThemeNudge
            } catch {
                weeklyShareSaveMessage = (error as? LocalizedError)?.errorDescription ?? "暂时没保存成功。请检查相册权限后再试。"
                showWeeklyShareThemeNudge = false
            }
            isSavingWeeklyShareCard = false
        }
    }
}

// MARK: - Weather Memory Backdrop

private struct WeatherMemoryBackdrop: View {
    enum Kind: Equatable {
        case rain
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let kind: Kind

    @ViewBuilder
    var body: some View {
        if reduceMotion {
            backdrop(time: 0, phase: 0, isAnimated: false)
                .allowsHitTesting(false)
        } else {
            TimelineView(.periodic(from: Date(), by: 1 / 12)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let phase = time.truncatingRemainder(dividingBy: 12) / 12
                backdrop(time: time, phase: phase, isAnimated: true)
            }
            .allowsHitTesting(false)
        }
    }

    private func backdrop(time: TimeInterval, phase: Double, isAnimated: Bool) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.45, green: 0.61, blue: 0.70).opacity(0.34),
                    Color(red: 0.72, green: 0.82, blue: 0.88).opacity(0.28),
                    Color(red: 0.28, green: 0.43, blue: 0.52).opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            movingMist(phase: phase)

            if kind == .rain {
                rainCanvas(time: time)
                    .opacity(isAnimated ? 0.42 : 0.24)
            }

            LinearGradient(
                colors: [
                    Color.white.opacity(0.34),
                    Color.white.opacity(0.02),
                    Color(red: 0.22, green: 0.36, blue: 0.44).opacity(0.12)
                ],
                startPoint: UnitPoint(x: isAnimated ? 0.1 + phase * 0.22 : 0.1, y: 0),
                endPoint: .bottomTrailing
            )
        }
        .saturation(0.92)
    }

    private func movingMist(phase: Double) -> some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color.white.opacity(0.38),
                    Color.white.opacity(0.12),
                    Color.white.opacity(0)
                ],
                center: .center,
                startRadius: 0,
                endRadius: 120
            )
            .frame(width: 220, height: 120)
            .offset(x: CGFloat(-72 + phase * 54), y: -34)
            .blur(radius: 8)

            RadialGradient(
                colors: [
                    Color(red: 0.78, green: 0.90, blue: 0.96).opacity(0.28),
                    Color.white.opacity(0.06),
                    Color.white.opacity(0)
                ],
                center: .center,
                startRadius: 0,
                endRadius: 150
            )
            .frame(width: 260, height: 150)
            .offset(x: CGFloat(80 - phase * 42), y: 54)
            .blur(radius: 12)
        }
    }

    private func rainCanvas(time: TimeInterval) -> some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let diagonalDrift = size.height * 0.20
            for index in 0..<42 {
                let seed = Double(index)
                let lane = (seed * 37).truncatingRemainder(dividingBy: 100) / 100
                let speed = 0.34 + (seed * 13).truncatingRemainder(dividingBy: 19) / 45
                let progress = (time * speed + seed * 0.071).truncatingRemainder(dividingBy: 1)
                let length = 10 + (seed * 11).truncatingRemainder(dividingBy: 14)
                let x = lane * size.width + progress * diagonalDrift - 26
                let y = progress * (size.height + 54) - 34
                let opacity = 0.18 + (seed * 7).truncatingRemainder(dividingBy: 11) / 70

                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + length * 0.32, y: y + length))
                context.stroke(
                    path,
                    with: .color(Color.white.opacity(opacity)),
                    style: StrokeStyle(lineWidth: seed.truncatingRemainder(dividingBy: 3) == 0 ? 1.15 : 0.8, lineCap: .round)
                )
            }
        }
    }
}

// MARK: - Keyword Bubble Cloud

private struct KeywordBubbleDraft {
    enum Source {
        case hero
        case userTitle
        case lifeMark
        case amountTitle
        case emotion
        case context
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
                text: Color(red: 0.12, green: 0.15, blue: 0.17).opacity(0.86)
            )
        case .transport, .entertainment:
            return .init(
                base: Color(red: 0.58, green: 0.67, blue: 0.76).opacity(baseOpacity),
                rim: Color(red: 0.45, green: 0.54, blue: 0.65).opacity(rimOpacity),
                glow: Color(red: 0.63, green: 0.75, blue: 0.83).opacity(glowOpacity),
                text: Color(red: 0.12, green: 0.15, blue: 0.17).opacity(0.85)
            )
        case .daily, .lodging, .health, .home, .other:
            return .init(
                base: Color(red: 0.50, green: 0.70, blue: 0.64).opacity(isTitle ? 0.34 : 0.22),
                rim: Color(red: 0.47, green: 0.68, blue: 0.62).opacity(rimOpacity),
                glow: Color(red: 0.50, green: 0.70, blue: 0.64).opacity(isTitle ? 0.20 : 0.13),
                text: Color(red: 0.12, green: 0.15, blue: 0.17).opacity(0.86)
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
        TimelineView(.periodic(from: Date(), by: 1 / 15)) { timeline in
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
    let cardTheme: ShareCardTheme

    private var t: ShareCardTheme { cardTheme }

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

        static func appTheme(_ theme: ResolvedThemeTokens) -> ShareCardTheme {
            ShareCardTheme(
                bgStart: theme.background,
                bgMid: theme.surfaceWarm,
                bgEnd: theme.backgroundGradientEnd,
                panelBg: theme.panelStrong,
                panelBorder: theme.stroke.opacity(0.72),
                paperShadow: theme.textSecondary,
                paperEdge: theme.surfaceMuted,
                accent: theme.accent,
                accentDeep: theme.accentDark,
                titleSub: theme.textTertiary,
                textMain: theme.textPrimary,
                textMuted: theme.textSecondary,
                footer: theme.textSecondary,
                footerSub: theme.textTertiary
            )
        }
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
        nickname: String = "叙账用户",
        theme: ShareCardTheme = .journal
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
        self.cardTheme = theme
    }

    init(payload: WeeklyShareCardPayload, isPetMode: Bool = true, nickname: String = "叙账用户", theme: ShareCardTheme = .journal) {
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
            nickname: nickname,
            theme: theme
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
